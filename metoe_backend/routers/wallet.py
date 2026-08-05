"""
钱包模块接口：充值订单创建 + 资金划转 + 钱包余额查询
"""
import time
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import get_current_user, require_permission, uid_int, enforce_owner_or_super
from core.audit import write_audit

router = APIRouter(prefix="/wallet", tags=["钱包账户"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


RECHARGE_AMOUNTS = [50, 100, 200, 500, 1000, 2000, 5000, 10000]
PAY_CHANNELS = ["balance", "alipay", "wechat", "usdt", "paypal"]


# ============ 钱包余额 ============
@router.get("/balance")
def wallet_balance(user=Depends(get_current_user)):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT balance, id, username, email FROM users WHERE id = ?",
            (uid_int(user),),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="用户不存在")
    return ok({
        "balance": f"{float(row['balance'] or 0):.2f}",
        "balanceNum": float(row["balance"] or 0),
        "userId": row["id"],
        "username": row["username"],
        "email": row["email"],
        "currency": "CNY",
    })


# ============ 充值：固定档位 + 自定义金额 ============
class RechargeCreateReq(BaseModel):
    amount: float = Field(gt=0, le=999999)
    pay_channel: str = "alipay"
    coupon_code: Optional[str] = None


@router.post("/recharge")
def create_recharge(req: RechargeCreateReq, request: Request, user=Depends(require_permission("wallet:recharge"))):
    if req.pay_channel not in PAY_CHANNELS:
        return fail("支付方式不支持")
    amount = round(float(req.amount), 2)
    if amount <= 0:
        return fail("充值金额需大于0")
    with get_conn() as conn:
        now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
        uid = uid_int(user)
        order_no = f"RC{int(time.time()*1000)}{uid}"
        pay_no = f"PR{int(time.time()*1000)}{uid}"
        discount = 0
        # 优惠券抵扣
        coupon_id = None
        final_amount = amount
        if req.coupon_code:
            coupon = conn.execute(
                "SELECT * FROM coupons WHERE code=? AND status='active'",
                (req.coupon_code.strip().upper(),),
            ).fetchone()
            if not coupon:
                return fail("优惠券不存在或已失效")
            from datetime import datetime as _dt
            if coupon["valid_from"] and _dt.strptime(now, "%Y-%m-%d %H:%M:%S") < _dt.strptime(coupon["valid_from"], "%Y-%m-%d %H:%M:%S"):
                return fail("优惠券尚未生效")
            if coupon["valid_until"] and _dt.strptime(now, "%Y-%m-%d %H:%M:%S") > _dt.strptime(coupon["valid_until"] + " 23:59:59", "%Y-%m-%d %H:%M:%S"):
                return fail("优惠券已过期")
            if coupon["usage_limit"] and (coupon["usage_count"] or 0) >= coupon["usage_limit"]:
                return fail("优惠券已达使用上限")
            if amount < (coupon["min_order"] or 0):
                return fail(f"订单金额需满 {coupon['min_order']:.2f} 才能使用该券")
            if coupon["type"] == "percent":
                discount = round(amount * (coupon["value"] / 100), 2)
                if coupon["max_discount"]:
                    discount = min(discount, coupon["max_discount"])
            elif coupon["type"] == "fixed":
                discount = coupon["value"]
            discount = min(discount, amount)
            final_amount = round(amount - discount, 2)
            coupon_id = coupon["id"]

        order_id = conn.execute(
            """INSERT INTO orders
               (order_no, user_id, product, category, qty, amount, discount, total, pay_method, status, lisa_provider)
               VALUES (?,?,?,?,?,?,?,?,?,?, 'wallet_recharge')""",
            (order_no, uid, f"账户充值 {amount:.2f} 元", "recharge", 1,
             amount, discount, final_amount, req.pay_channel, "pending"),
        ).lastrowid

        pay_id = conn.execute(
            """INSERT INTO payments
               (pay_no, order_id, order_no, user_id, channel, amount, currency, status)
               VALUES (?,?,?,?,?,?, 'CNY', 'pending')""",
            (pay_no, order_id, order_no, uid, req.pay_channel, final_amount),
        ).lastrowid

        if coupon_id:
            conn.execute(
                "INSERT OR IGNORE INTO coupon_redemptions (coupon_id, user_id, order_id, code, discount_amount, original_amount, final_amount) VALUES (?,?,?,?,?,?,?)",
                (coupon_id, uid, order_id, req.coupon_code.upper(), discount, amount, final_amount),
            )
            conn.execute("UPDATE coupons SET usage_count = usage_count + 1 WHERE id=?", (coupon_id,))

        # 模拟支付：余额直接扣；其他渠道 pending 等待回调
        if req.pay_channel == "balance":
            user_row = conn.execute("SELECT balance FROM users WHERE id=?", (uid,)).fetchone()
            if float(user_row["balance"] or 0) < final_amount:
                return fail("余额不足，请先充值")
            balance_before = float(user_row["balance"] or 0)
            balance_after = round(balance_before - 0, 2)  # 充值不从余额扣，这里保持不变
            # 充值余额模式：把充值金额加回余额（相当于通过余额渠道完成的是内部转移，实际是充值加钱）
            balance_after = round(balance_before + amount, 2)
            conn.execute(
                "UPDATE users SET balance=?, updated_at=datetime('now','localtime') WHERE id=?",
                (balance_after, uid),
            )
            conn.execute(
                "UPDATE orders SET status='paid', paid_at=datetime('now','localtime') WHERE id=?",
                (order_id,),
            )
            conn.execute(
                "UPDATE payments SET status='paid', paid_at=datetime('now','localtime'), channel_txn_id=? WHERE id=?",
                (f"BAL_{order_no}", pay_id),
            )
            txn_id = conn.execute(
                """INSERT INTO transactions (user_id, type, amount, balance_before, balance_after, order_id, payment_id, remark)
                   VALUES (?,?,?,?,?,?,?,?)""",
                (uid, "recharge", amount, balance_before, balance_after, order_id, pay_id,
                 f"充值 {amount:.2f} 元（余额渠道）{f' 券抵扣{discount:.2f}' if discount>0 else ''}"),
            ).lastrowid
            write_audit(user, action="finance_recharge", level="mid", resource_type="recharge",
                        resource_id=str(order_id), ip=request.client.host if request.client else None,
                        ua=request.headers.get("user-agent"),
                        summary=f"充值成功 ¥{amount:.2f}，渠道=余额{f' 券抵扣¥{discount:.2f}' if discount>0 else ''}",
                        new={"amount": amount, "discount": discount, "channel": "balance"})
            return ok({
                "orderId": order_id, "orderNo": order_no, "payNo": pay_no,
                "amount": f"{final_amount:.2f}", "originalAmount": f"{amount:.2f}",
                "discount": f"{discount:.2f}", "status": "paid",
                "balanceAfter": f"{balance_after:.2f}", "transactionId": txn_id,
            }, "充值成功")
        else:
            # 其他渠道返回 pending，前端跳收银台（这里 mock 一份地址）
            mock_urls = {
                "alipay": f"https://openapi.alipay.com/gateway/mock?order={order_no}",
                "wechat": f"weixin://wxpay/bizpayurl?pr=MOCK_{order_no}",
                "usdt": f"usdt:TRC20:TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE?amount={final_amount}&label={order_no}",
                "paypal": f"https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_xclick&amount={final_amount}&invoice={order_no}",
            }
            return ok({
                "orderId": order_id, "orderNo": order_no, "payNo": pay_no,
                "amount": f"{final_amount:.2f}", "originalAmount": f"{amount:.2f}",
                "discount": f"{discount:.2f}", "status": "pending",
                "payChannel": req.pay_channel,
                "payUrl": mock_urls.get(req.pay_channel, ""),
                "expireAt": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time() + 1800)),
            }, "已创建充值订单，请前往支付")


@router.get("/recharge-options")
def recharge_options(user=Depends(get_current_user)):
    return ok({
        "amounts": RECHARGE_AMOUNTS,
        "channels": [
            {"code": "alipay", "name": "支付宝", "icon": "CreditCard", "enabled": True, "min": 1, "max": 50000},
            {"code": "wechat", "name": "微信支付", "icon": "ChatDotSquare", "enabled": True, "min": 1, "max": 50000},
            {"code": "usdt", "name": "USDT (TRC20)", "icon": "Coin", "enabled": True, "min": 50, "max": 500000},
            {"code": "paypal", "name": "PayPal", "icon": "Wallet", "enabled": True, "min": 50, "max": 100000},
            {"code": "balance", "name": "余额（内部测试）", "icon": "WalletFilled", "enabled": True, "min": 1, "max": 10000},
        ],
        "promotions": [
            {"title": "新用户首充赠", "desc": "首次充值满 200 送 20", "rule": "首次充值单笔≥200到账后自动发放"},
            {"title": "大额充值返现", "desc": "单笔 1000 返 3%，5000 返 5%", "rule": "实时到账，可叠加优惠券"},
        ],
    })


# ============ 资金划转 ============
class TransferReq(BaseModel):
    to_username: str = Field(min_length=3, max_length=20)
    amount: float = Field(gt=0, le=100000)
    remark: Optional[str] = None
    pay_password: Optional[str] = None


@router.post("/transfer")
def wallet_transfer(req: TransferReq, request: Request, user=Depends(require_permission("wallet:transfer"))):
    uid = uid_int(user)
    from_username = user.get("username") or ""
    amount = round(float(req.amount), 2)
    if amount <= 0:
        return fail("划转金额需大于0")
    with get_conn() as conn:
        to_user = conn.execute(
            "SELECT id, username, status FROM users WHERE username=?",
            (req.to_username.strip(),),
        ).fetchone()
        if not to_user:
            return fail("目标用户不存在")
        if to_user["status"] != "active":
            return fail("目标账号已被禁用")
        to_uid = to_user["id"]
        to_username = to_user["username"]
        if to_uid == uid:
            return fail("不能划转给本人")

        # 强约束：仅允许主账号 → 子账号 划转
        # 规则 1：当前用户必须是转出方（uid == parent_id）
        # 规则 2：目标用户必须是当前用户的子账号（user_relationships 有明确父子关系）
        # 禁止：子→主、主→主（peer）、任意无关系用户
        rel = conn.execute(
            "SELECT * FROM user_relationships WHERE parent_id=? AND child_id=?",
            (uid, to_uid),
        ).fetchone()
        if not rel:
            # 额外校验：目标账号本身是子账号（有 child_id 记录），但父账号不是当前用户
            child_any = conn.execute(
                "SELECT * FROM user_relationships WHERE child_id=?", (to_uid,)
            ).fetchone()
            if child_any:
                return fail("该子账号不属于当前主账号，不能划转")
            # 目标账号没有父子关系记录 → 说明是主账号/普通对等账号 → 禁止
            # 同时也校验：如果当前用户自己是子账号，禁止其发起任何划转
            i_am_child = conn.execute(
                "SELECT * FROM user_relationships WHERE child_id=?", (uid,)
            ).fetchone()
            if i_am_child:
                return fail("子账号不能发起资金划转，请使用主账号操作")
            return fail("只能向自己的子账号划转资金，主账号间禁止互转")

        transfer_type = "parent_to_child"

        from_user = conn.execute("SELECT balance, username FROM users WHERE id=?", (uid,)).fetchone()
        if float(from_user["balance"] or 0) < amount:
            return fail("余额不足")
        if from_user.get("username"):
            from_username = from_user["username"]

        balance_from_before = float(from_user["balance"] or 0)
        balance_from_after = round(balance_from_before - amount, 2)
        balance_to_before = float(conn.execute("SELECT balance FROM users WHERE id=?", (to_uid,)).fetchone()["balance"] or 0)
        balance_to_after = round(balance_to_before + amount, 2)

        transfer_no = f"TF{int(time.time()*1000)}{uid}{to_uid}"
        now_local = "datetime('now','localtime')"
        currency = "CNY"

        conn.execute(f"UPDATE users SET balance={balance_from_after}, updated_at={now_local} WHERE id={uid}")
        conn.execute(f"UPDATE users SET balance={balance_to_after}, updated_at={now_local} WHERE id={to_uid}")

        tf_id = conn.execute(
            """INSERT INTO transfers
               (transfer_no, from_user_id, to_user_id, from_username, to_username, currency,
                amount, fee, type, remark, status)
               VALUES (?,?,?,?,?,?,?,0,?,?, 'completed')""",
            (transfer_no, uid, to_uid, from_username, to_username, currency,
             amount, transfer_type, (req.remark or "")[:200]),
        ).lastrowid

        # 双方交易流水
        tx_out_id = conn.execute(
            f"""INSERT INTO transactions (user_id, type, amount, balance_before, balance_after, remark)
               VALUES ({uid}, 'transfer_out', {-amount}, {balance_from_before}, {balance_from_after}, ?)""",
            (f"划转至 {to_username}（{transfer_no}）{f'：{req.remark}' if req.remark else ''}",),
        ).lastrowid
        tx_in_id = conn.execute(
            f"""INSERT INTO transactions (user_id, type, amount, balance_before, balance_after, remark)
               VALUES ({to_uid}, 'transfer_in', {amount}, {balance_to_before}, {balance_to_after}, ?)""",
            (f"收到 {from_username} 划转（{transfer_no}）{f'：{req.remark}' if req.remark else ''}",),
        ).lastrowid

        # 子账号专属余额记录
        conn.execute(
            "UPDATE user_relationships SET current_balance = current_balance + ?, updated_at=datetime('now','localtime') WHERE parent_id=? AND child_id=?",
            (amount, uid, to_uid),
        )

        # 通知目标用户
        conn.execute(
            """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
               VALUES (?, 'wallet', '收到一笔资金划转', ?, 'success', 'transfer', ?)""",
            (to_uid, f"{from_username} 向您划转了 ¥{amount:.2f}（{currency}）{f'，备注：{req.remark}' if req.remark else ''}", str(tf_id)),
        )

        write_audit(user, action="finance_recharge", level="mid", resource_type="transfer",
                    resource_id=str(tf_id), ip=request.client.host if request.client else None,
                    ua=request.headers.get("user-agent"),
                    summary=f"{from_username} 向子账号 {to_username} 划转 ¥{amount:.2f} ({currency})",
                    new={"from": from_username, "to": to_username, "amount": amount,
                         "currency": currency, "type": transfer_type})

    return ok({
        "transferId": tf_id, "transferNo": transfer_no,
        "fromUsername": from_username, "fromUserId": uid,
        "toUsername": to_username, "toUserId": to_uid,
        "amount": f"{amount:.2f}", "currency": currency, "type": transfer_type,
        "balanceAfter": f"{balance_from_after:.2f}",
        "targetBalanceAfter": f"{balance_to_after:.2f}",
        "toBalanceAfter": f"{balance_to_after:.2f}",
        "txOutId": tx_out_id, "txInId": tx_in_id,
    }, "划转成功")


@router.get("/transfers")
def transfers_list(
    direction: Optional[str] = None,
    page: int = 1, page_size: int = 20,
    user=Depends(get_current_user),
):
    uid = uid_int(user)
    wh, params = [], []
    if direction == "out":
        wh.append("from_user_id = ?"); params.append(uid)
    elif direction == "in":
        wh.append("to_user_id = ?"); params.append(uid)
    else:
        wh.append("(from_user_id = ? OR to_user_id = ?)"); params.extend([uid, uid])
    where = "WHERE " + " AND ".join(wh)
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM transfers {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT t.*, fu.username from_name, tu.username to_name
                  FROM transfers t
             LEFT JOIN users fu ON fu.id = t.from_user_id
             LEFT JOIN users tu ON tu.id = t.to_user_id
                  {where}
              ORDER BY t.id DESC LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        is_out = r["from_user_id"] == uid
        list_.append({
            "id": r["id"], "transferNo": r["transfer_no"],
            "direction": "out" if is_out else "in",
            "fromUserId": r["from_user_id"],
            "fromName": r.get("from_username") or r["from_name"],
            "fromUsername": r.get("from_username") or r["from_name"],
            "toUserId": r["to_user_id"],
            "toName": r.get("to_username") or r["to_name"],
            "toUsername": r.get("to_username") or r["to_name"],
            "currency": r.get("currency") or "CNY",
            "amount": f"{float(r['amount']):.2f}", "fee": f"{float(r['fee']):.2f}",
            "type": r["type"], "remark": r["remark"],
            "status": r["status"], "createdAt": r["created_at"],
            "counterparty": (r.get("to_username") or r["to_name"]) if is_out else (r.get("from_username") or r["from_name"]),
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})
