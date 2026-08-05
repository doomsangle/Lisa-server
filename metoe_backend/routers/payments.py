"""支付接口：余额支付 / 模拟支付 / 支付宝 / 微信 / USDT(TRC20) / PayPal
   支付成功后触发 Lisa主机 API 下单 + vpn.sh 脚本部署 VPS 流水线"""
import time, random, uuid, json, math
from fastapi import APIRouter, HTTPException, Depends, Query, Request
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

from core.database import get_conn
from core.security import require_permission, get_current_user, scope_uid, enforce_owner_or_super
from core.audit import audit_payment_success, audit_order_create

router = APIRouter(prefix="/payments", tags=["支付"])


# ============= Pydantic Models =============
class PayCreateReq(BaseModel):
    order_id: Optional[int] = None
    order_no: Optional[str] = None
    channel: str = "balance"  # balance / mock / alipay / wechat / usdt / paypal
    return_url: Optional[str] = None
    cancel_url: Optional[str] = None


class PayNotifyReq(BaseModel):
    pay_no: str
    status: str = "success"
    channel_txn_id: Optional[str] = None
    raw: Optional[dict] = None


class PaypalAmount(BaseModel):
    currency_code: str = "USD"
    value: str


class PaypalPayer(BaseModel):
    email_address: Optional[str] = None
    name: Optional[Dict[str, str]] = None


class PaypalPurchaseUnit(BaseModel):
    reference_id: Optional[str] = None
    description: Optional[str] = None
    amount: PaypalAmount


class PaypalOrderCreate(BaseModel):
    intent: str = "CAPTURE"
    payer: Optional[PaypalPayer] = None
    purchase_units: List[PaypalPurchaseUnit]
    application_context: Optional[Dict[str, Any]] = None


class UsdtNotifyReq(BaseModel):
    pay_no: Optional[str] = None
    txid: str
    network: str = "TRC20"
    amount: float
    from_address: Optional[str] = None
    to_address: Optional[str] = None
    confirmations: int = 1


# ============= Helper =============
def _make_pay_no():
    return f"PAY{int(time.time()*1000)}{random.randint(100,999)}"


def _paypal_order_id():
    return "5O1" + "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", k=14))


def _usdt_txid():
    return "0x" + "".join(random.choices("0123456789abcdef", k=62))


def _get_order(conn, user, order_id, order_no):
    if order_id:
        row = conn.execute("SELECT * FROM orders WHERE id=? AND user_id=?", (order_id, user["id"])).fetchone()
    elif order_no:
        row = conn.execute("SELECT * FROM orders WHERE order_no=? AND user_id=?", (order_no, user["id"])).fetchone()
    else:
        raise HTTPException(400, "order_id 或 order_no 必传其一")
    if not row:
        raise HTTPException(404, "订单不存在或无权访问")
    return row


def _build_channel_name(c):
    return {
        "balance": "余额支付",
        "mock": "模拟支付(测试)",
        "alipay": "支付宝",
        "wechat": "微信支付",
        "usdt": "USDT(TRC20)",
        "paypal": "PayPal",
    }.get(c, c)


def _sys_cfg(conn, key, default=""):
    r = conn.execute("SELECT value FROM system_configs WHERE key=?", (key,)).fetchone()
    if r is None or r["value"] is None or r["value"] == "":
        return default
    return r["value"]


def _settle_payment_success(conn, pay_no, channel_txn_id=None, raw_callback: Optional[dict] = None):
    """所有支付渠道（PayPal/USDT/Wechat/Alipay/Mock）成功后统一走此函数：
       更新 payments -> transactions -> orders -> 触发Lisa主机下单+VPN部署
    """
    p = conn.execute("SELECT * FROM payments WHERE pay_no=?", (pay_no,)).fetchone()
    if not p:
        raise HTTPException(404, "支付单不存在")
    if p["status"] == "paid":
        order = conn.execute("SELECT * FROM orders WHERE id=?", (p["order_id"],)).fetchone()
        deploy = conn.execute("SELECT id,task_no FROM deploy_tasks WHERE order_id=? LIMIT 1",
                              (p["order_id"],)).fetchone()
        return {
            "paid": True, "pay_no": pay_no,
            "order_no": order["order_no"] if order else None,
            "deploy_id": deploy["id"] if deploy else None,
            "task_no": deploy["task_no"] if deploy else None,
            "already_paid": True,
        }
    order = conn.execute("SELECT * FROM orders WHERE id=?", (p["order_id"],)).fetchone()
    if not order:
        raise HTTPException(404, "关联订单不存在")
    user = conn.execute("SELECT * FROM users WHERE id=?", (order["user_id"],)).fetchone()

    # 1) payments: status=paid, txn_id, paid_at, raw_callback
    conn.execute(
        "UPDATE payments SET status='paid', channel_txn_id=?, paid_at=datetime('now','localtime'), raw_callback=? WHERE pay_no=?",
        (channel_txn_id, json.dumps(raw_callback or {}, ensure_ascii=False)[:2000], pay_no),
    )

    # 2) orders: status=paid, pay_method, paid_at
    conn.execute(
        "UPDATE orders SET status='paid', pay_method=?, paid_at=datetime('now','localtime') WHERE id=?",
        (p["channel"], order["id"]),
    )

    # 3) transactions: 记流水（渠道支付不改变用户余额，故前后不变）
    conn.execute(
        "INSERT INTO transactions (user_id,type,amount,balance_before,balance_after,order_id,payment_id,remark) "
        "VALUES (?,'pay',?,?,?,?,?,?)",
        (order["user_id"], float(p["amount"]), float(user["balance"]), float(user["balance"]),
         order["id"], p["id"], f"{_build_channel_name(p['channel'])}支付成功：订单{order['order_no']}，渠道单号{channel_txn_id or '-'}"),
    )

    # 4) 触发Lisa主机下单 & 部署流水线
    from services.pipeline import trigger_lisa_and_deploy
    deploy_task = trigger_lisa_and_deploy(conn, order["id"], dict(user))

    # 5) 合规审计（事务内写入：_conn 传参共享同一个连接）
    channel_name = _build_channel_name(p["channel"])
    old_bal = float(user["balance"])
    try:
        # 充值订单（order.order_no 前缀 R 说明是余额充值；购买套餐则为 P/EC 等）
        is_recharge = order.get("category") == "recharge" or (order.get("order_no") or "").startswith("R")
        audit_payment_success(
            user,
            resource_type="payment",
            resource_id=p["pay_no"],
            old={"status": p["status"]},
            new={
                "status": "paid",
                "channel": p["channel"],
                "amount": float(p["amount"]),
                "order_no": order.get("order_no"),
                "deploy_id": deploy_task.get("deploy_id"),
                "server_id": deploy_task.get("server_id"),
            },
            summary=f"{channel_name}支付成功：¥{float(p['amount']):.2f}（订单 {order.get('order_no')}，渠道单号 {channel_txn_id or '-'}）"
                     + (" · 余额充值到账" if is_recharge else f" · 自动部署 task#{deploy_task.get('task_no')}"),
            _conn=conn,
        )
    except Exception:
        pass

    return {
        "paid": True,
        "pay_no": pay_no,
        "order_id": order["id"],
        "order_no": order["order_no"],
        "channel": p["channel"],
        "channel_txn_id": channel_txn_id,
        "deploy_id": deploy_task["deploy_id"],
        "task_no": deploy_task["task_no"],
        "server_id": deploy_task.get("server_id"),
        "proxy_ids": deploy_task.get("proxy_ids"),
    }


# ============= create_payment: 统一入口 =============
def do_create_payment(conn, order, user, channel, return_url=None, cancel_url=None):
    """供 orders router 与本路由复用的支付创建核心逻辑
       返回: {"code":..., "message":..., "data":...}
    """
    if order["status"] == "paid":
        return {"code": 200, "message": "该订单已支付", "data": {"paid": True, "order_no": order["order_no"]}}
    if order["status"] not in ("pending", "created"):
        raise HTTPException(400, f"订单状态异常：{order['status']}")

    amount_cny = float(order["total"])
    if channel == "balance":
        if float(user["balance"]) < amount_cny:
            raise HTTPException(400, f"余额不足，当前余额¥{user['balance']:.2f}，应付¥{amount_cny:.2f}")
        bal_before = float(user["balance"])
        bal_after = bal_before - amount_cny
        conn.execute("UPDATE users SET balance=? WHERE id=?", (bal_after, user["id"]))
        pay_no = _make_pay_no()
        conn.execute(
            "INSERT INTO payments (pay_no,order_id,order_no,user_id,channel,amount,currency,status,paid_at) "
            "VALUES (?,?,?,?,?,?,'CNY','paid',datetime('now','localtime'))",
            (pay_no, order["id"], order["order_no"], user["id"], "balance", amount_cny),
        )
        conn.execute(
            "INSERT INTO transactions (user_id,type,amount,balance_before,balance_after,order_id,remark) "
            "VALUES (?,'pay',?,?,?,?,?)",
            (user["id"], amount_cny, bal_before, bal_after, order["id"],
             f"订单支付：{order['product']}（余额支付）"),
        )
        conn.execute(
            "UPDATE orders SET status='paid', pay_method='balance', paid_at=datetime('now','localtime') WHERE id=?",
            (order["id"],),
        )
        from services.pipeline import trigger_lisa_and_deploy
        deploy_task = trigger_lisa_and_deploy(conn, order["id"], user)
        return {"code": 200, "message": "余额支付成功，已开始部署", "data": {
            "paid": True,
            "pay_no": pay_no,
            "order_no": order["order_no"],
            "order_id": order["id"],
            "deploy_id": deploy_task["deploy_id"],
            "task_no": deploy_task.get("task_no"),
            "server_id": deploy_task.get("server_id"),
            "vps_ip": deploy_task.get("vps_ip"),
        }}

    pay_no = _make_pay_no()
    expire_ts = time.time() + int(_sys_cfg(conn, "usdt_order_expire_min", "30")) * 60
    try:
        cny_per_usd = float(_sys_cfg(conn, "usdt_cny_usd_rate", "7.25"))
    except Exception:
        cny_per_usd = 7.25
    amount_usd = round(amount_cny / cny_per_usd, 4)

    if channel == "paypal":
        currency = _sys_cfg(conn, "paypal_currency", "USD").upper() or "USD"
        try:
            pp_fee_rate = float(_sys_cfg(conn, "paypal_fee_rate", "0.044"))
            pp_fee_fixed = float(_sys_cfg(conn, "paypal_fixed_fee_usd", "0.3"))
        except Exception:
            pp_fee_rate, pp_fee_fixed = 0.044, 0.3
        amount_for_pp = amount_usd if currency == "USD" else amount_cny
        fee_usd = round(amount_usd * pp_fee_rate + pp_fee_fixed, 4)
        total_usd_with_fee = round(amount_usd + fee_usd, 4)
        pp_mode = _sys_cfg(conn, "paypal_mode", "sandbox")
        pp_client_id = _sys_cfg(conn, "paypal_client_id")
        pp_order_id = _paypal_order_id()
        approve_link = (
            f"https://www.sandbox.paypal.com/checkoutnow?token={pp_order_id}"
            if pp_mode != "live" else f"https://www.paypal.com/checkoutnow?token={pp_order_id}"
        )
        paypal_order = {
            "id": pp_order_id, "intent": "CAPTURE", "status": "CREATED",
            "purchase_units": [{
                "reference_id": f"REF{order['order_no']}", "description": order["product"],
                "amount": {
                    "currency_code": currency, "value": f"{amount_for_pp:.2f}",
                    "breakdown": {
                        "item_total": {"currency_code": currency, "value": f"{amount_for_pp:.2f}"},
                        "handling": {"currency_code": "USD", "value": f"{fee_usd:.2f}"},
                    },
                },
                "custom_id": pay_no, "invoice_id": order["order_no"],
            }],
            "create_time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "links": [
                {"href": approve_link, "rel": "approve", "method": "GET"},
                {"href": f"/payments/paypal/v2/orders/{pp_order_id}", "rel": "self", "method": "GET"},
                {"href": f"/payments/paypal/v2/orders/{pp_order_id}/capture", "rel": "capture", "method": "POST"},
            ],
        }
        conn.execute(
            "INSERT INTO payments (pay_no,order_id,order_no,user_id,channel,amount,currency,status,remark,channel_txn_id) "
            "VALUES (?,?,?,?,?,?,'USD','pending',?,?)",
            (pay_no, order["id"], order["order_no"], user["id"], "paypal", amount_cny,
             f"PayPal订单:{pp_order_id}; 汇率{round(cny_per_usd,4)}; 手续费${fee_usd:.2f}", pp_order_id),
        )
        return {"code": 200, "message": "PayPal订单创建成功，前往官方页面完成支付", "data": {
            "paid": False, "pay_no": pay_no, "order_no": order["order_no"], "order_id": order["id"],
            "channel": "paypal", "channel_name": "PayPal",
            "amount": amount_cny, "amount_currency": "CNY",
            "settle": {
                "currency": currency, "amount": round(amount_for_pp, 4),
                "fee_usd": fee_usd, "total_usd": total_usd_with_fee,
                "cny_per_usd": cny_per_usd,
            },
            "paypal": {
                "mode": pp_mode, "client_id": pp_client_id,
                "order": paypal_order, "order_id": pp_order_id, "approval_url": approve_link,
            },
            "qr_data": approve_link,
            "expire_at": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(expire_ts)),
            "confirm_endpoints": {
                "capture": f"/payments/paypal/v2/orders/{pp_order_id}/capture",
                "test_confirm": f"/payments/paypal-confirm?pay_no={pay_no}",
            },
            "return_url": return_url, "cancel_url": cancel_url,
            "mock_confirm": f"/payments/mock-confirm?pay_no={pay_no}",
            "mock_confirm_url": f"/payments/mock-confirm?pay_no={pay_no}",
        }}

    if channel == "usdt":
        network = _sys_cfg(conn, "usdt_network", "TRC20")
        wallet = _sys_cfg(conn, "usdt_wallet_address", "")
        uniq_tail = float(f"0.000{int(pay_no[-8:]) % 9999}") / 10000.0
        amount_usdt = round(amount_usd + uniq_tail, 8)
        if network.upper() == "TRC20":
            qr_uri = f"tron:{wallet}?value={int(amount_usdt*1e6)}&token=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        else:
            qr_uri = f"ethereum:{wallet}?value={amount_usdt}&contractAddress=0xdAC17F958D2ee523a2206206994597C13D831ec7"
        min_cfm = int(_sys_cfg(conn, "usdt_min_confirm", "1"))
        expire_min = int(_sys_cfg(conn, "usdt_order_expire_min", "30"))
        conn.execute(
            "INSERT INTO payments (pay_no,order_id,order_no,user_id,channel,amount,currency,status,remark) "
            "VALUES (?,?,?,?,?,?,'USDT','pending',?)",
            (pay_no, order["id"], order["order_no"], user["id"], "usdt", amount_cny,
             f"USDT({network}): {amount_usdt} USDT  ->  {wallet}  (汇率 {round(cny_per_usd,4)})"),
        )
        return {"code": 200, "message": "请在有效期内使用指定网络完成USDT转账", "data": {
            "paid": False, "pay_no": pay_no, "order_no": order["order_no"], "order_id": order["id"],
            "channel": "usdt", "channel_name": f"USDT({network})",
            "amount_cny": amount_cny,
            "settle": {
                "network": network.upper(), "amount_usdt": amount_usdt,
                "amount_usd": amount_usd, "cny_per_usd": cny_per_usd,
            },
            "wallet": {
                "network": network.upper(), "currency": "USDT",
                "address": wallet, "amount": f"{amount_usdt:.8f}", "amount_raw": amount_usdt,
                "memo": pay_no, "min_confirmations": min_cfm,
            },
            "qr_uri": qr_uri, "qr_data": qr_uri,
            "expire_at": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(expire_ts)),
            "expire_min": expire_min,
            "tips": [
                f"务必使用 {network.upper()} 网络，使用其他网络转账将无法识别且不可找回",
                f"请在 {expire_min} 分钟内完成转账并确保到账金额精确到尾号",
                "转账后1-2分钟自动识别成功，也可手动点“我已支付”刷新状态",
            ],
            "confirm_endpoints": {
                "notify": "/payments/usdt/notify",
                "query": f"/payments/usdt/check?pay_no={pay_no}",
                "test_confirm": f"/payments/usdt-confirm?pay_no={pay_no}",
            },
            "mock_confirm": f"/payments/mock-confirm?pay_no={pay_no}",
            "mock_confirm_url": f"/payments/mock-confirm?pay_no={pay_no}",
        }}

    # mock / alipay / wechat
    conn.execute(
        "INSERT INTO payments (pay_no,order_id,order_no,user_id,channel,amount,currency,status) "
        "VALUES (?,?,?,?,?,?,'CNY','pending')",
        (pay_no, order["id"], order["order_no"], user["id"], channel, amount_cny),
    )
    qr_or_url = ""
    if channel == "mock":
        qr_or_url = f"MOCK_PAYMENT_QR_DATA_" + pay_no
        conn.execute(
            "UPDATE payments SET remark=? WHERE pay_no=?",
            (f"模拟支付：调用 /payments/mock-confirm?pay_no={pay_no} 确认", pay_no),
        )
    elif channel == "alipay":
        qr_or_url = f"https://qr.alipay.com/bax0{pay_no.lower()}"
    elif channel == "wechat":
        qr_or_url = f"weixin://wxpay/bizpayurl?pr=M{pay_no[-10:]}"
    else:
        raise HTTPException(400, "不支持的支付渠道")
    return {"code": 200, "message": "支付单已创建，请完成支付", "data": {
        "paid": False, "pay_no": pay_no, "order_no": order["order_no"], "order_id": order["id"],
        "amount": amount_cny, "channel": channel, "channel_name": _build_channel_name(channel),
        "qr_data": qr_or_url,
        "expire_at": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(expire_ts)),
        "mock_confirm": f"/payments/mock-confirm?pay_no={pay_no}" if channel == "mock" else None,
        "mock_confirm_url": f"/payments/mock-confirm?pay_no={pay_no}" if channel == "mock" else None,
    }}


@router.post("/create")
def create_payment(req: PayCreateReq, user=Depends(get_current_user)):
    """创建支付单（前端统一入口）"""
    with get_conn() as conn:
        order = _get_order(conn, user, req.order_id, req.order_no)
        return do_create_payment(conn, order, user, req.channel,
                                 return_url=req.return_url, cancel_url=req.cancel_url)

# ============= 通用确认（保持兼容） =============
@router.get("/mock-confirm")
def mock_confirm_pay(pay_no: str):
    """通用模拟支付确认，适用于 mock/alipay/wechat/usdt/paypal —— 测试/演示时点“已付款”使用。
       生产环境应使用各渠道官方回调。"""
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE pay_no=?", (pay_no,)).fetchone()
        if not p:
            raise HTTPException(404, "支付单不存在")
        if p["status"] == "paid":
            return {"code": 200, "message": "已支付，无需重复", "data": {"pay_no": pay_no, "paid": True}}
        ch = p["channel"]
        if ch == "mock":
            txn = f"MOCK_TXN_" + uuid.uuid4().hex[:12].upper()
        elif ch == "alipay":
            txn = "202" + "".join(random.choices("0123456789", k=16))
        elif ch == "wechat":
            txn = "420" + "".join(random.choices("0123456789", k=20))
        elif ch == "usdt":
            txn = _usdt_txid()
        elif ch == "paypal":
            txn = "9XL" + "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", k=14))
        else:
            txn = f"TXN_{uuid.uuid4().hex[:16].upper()}"
        settled = _settle_payment_success(conn, pay_no, channel_txn_id=txn,
                                          raw_callback={"type": "mock_confirm", "by": ch})
    return {"code": 200, "message": f"✓ {_build_channel_name(ch)} 模拟支付成功，已开始自动部署",
            "data": settled}


# ============= PayPal：官方风格 v2 Orders / Capture / Webhook =============
@router.post("/paypal/v2/orders")
def paypal_v2_create_order(body: PaypalOrderCreate, request: Request):
    """PayPal Orders v2 创建订单（与官方API同构，可直接在前端 @paypal/js-sdk 中通过 fetch 调用）"""
    with get_conn() as conn:
        pu0 = body.purchase_units[0]
        pu0d = pu0.dict()
        custom_id = pu0d.get("custom_id")
        app_ctx = body.application_context or {}
        pay_no = custom_id or (app_ctx.get("custom_id") if isinstance(app_ctx, dict) else None)

        if pay_no:
            p = conn.execute("SELECT * FROM payments WHERE pay_no=?", (pay_no,)).fetchone()
            if not p:
                raise HTTPException(404, "pay_no not found")
            ref_id = p["order_no"]
            amt_val = float(body.purchase_units[0].amount.value)
            cur = body.purchase_units[0].amount.currency_code
        else:
            ref_id = "no_ref_" + uuid.uuid4().hex[:8]
            amt_val = float(body.purchase_units[0].amount.value)
            cur = body.purchase_units[0].amount.currency_code

        order_id = _paypal_order_id()
        mode = _sys_cfg(conn, "paypal_mode", "sandbox")
        base = (f"https://api-m.sandbox.paypal.com"
                if mode != "live" else "https://api-m.paypal.com")
        approve_link = (
            f"https://www.sandbox.paypal.com/checkoutnow?token={order_id}"
            if mode != "live" else f"https://www.paypal.com/checkoutnow?token={order_id}"
        )
        resp = {
            "id": order_id,
            "status": "CREATED",
            "intent": "CAPTURE",
            "purchase_units": [{
                "reference_id": pu0.reference_id or ref_id,
                "amount": {"currency_code": cur, "value": f"{amt_val:.2f}"},
                "description": pu0.description,
            }],
            "create_time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "links": [
                {"href": f"{base}/v2/checkout/orders/{order_id}", "rel": "self", "method": "GET"},
                {"href": approve_link, "rel": "approve", "method": "GET"},
                {"href": f"{base}/v2/checkout/orders/{order_id}", "rel": "update", "method": "PATCH"},
                {"href": f"{base}/v2/checkout/orders/{order_id}/capture", "rel": "capture", "method": "POST"},
            ],
        }
        # 记录到 payments.channel_txn_id （如果关联了pay_no）
        if pay_no:
            conn.execute("UPDATE payments SET channel_txn_id=? WHERE pay_no=?", (order_id, pay_no))
    return resp


@router.get("/paypal/v2/orders/{order_id}")
def paypal_v2_get_order(order_id: str):
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE channel_txn_id=? AND channel='paypal'",
                         (order_id,)).fetchone()
        if not p:
            return {"id": order_id, "status": "CREATED", "intent": "CAPTURE"}
        amt_val = round(float(p["amount"]) / float(_sys_cfg(conn, "usdt_cny_usd_rate", "7.25")), 2)
        return {
            "id": order_id,
            "status": "APPROVED" if p["status"] == "paid" else "CREATED",
            "purchase_units": [{"amount": {"currency_code": "USD", "value": f"{amt_val:.2f}"}}],
            "custom_id": p["pay_no"],
        }


@router.post("/paypal/v2/orders/{order_id}/capture")
def paypal_v2_capture_order(order_id: str):
    """PayPal Orders v2 Capture（用户在官方页面批准后，服务端捕获资金 => 标记成功+部署）"""
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE channel_txn_id=? AND channel='paypal'",
                         (order_id,)).fetchone()
        if not p:
            raise HTTPException(404, {"name": "INVALID_RESOURCE_ID", "message": "Order id not found"})
        capture_id = "8FT" + "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", k=14))
        settled = _settle_payment_success(conn, p["pay_no"],
                                          channel_txn_id=capture_id,
                                          raw_callback={"event_type": "PAYMENT.CAPTURE.COMPLETED",
                                                        "order_id": order_id,
                                                        "capture_id": capture_id})
    amt_usd = round(float(p["amount"]) / float(_sys_cfg(conn, "usdt_cny_usd_rate", "7.25")), 2)
    return {
        "id": order_id,
        "status": "COMPLETED",
        "purchase_units": [{
            "reference_id": settled["order_no"],
            "payments": {
                "captures": [{
                    "id": capture_id,
                    "status": "COMPLETED",
                    "amount": {"currency_code": "USD", "value": f"{amt_usd:.2f}"},
                    "create_time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "update_time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }],
            },
        }],
        "payer": {"email_address": "demo-buyer@sandbox.paypal.com"},
        "internal": {"deploy_id": settled["deploy_id"], "task_no": settled["task_no"]},
    }


@router.post("/paypal/webhook")
async def paypal_webhook(request: Request):
    """模拟 PayPal IPN/Webhook：接收 CHECKOUT.ORDER.COMPLETED / PAYMENT.CAPTURE.COMPLETED"""
    payload = await request.json()
    evt = payload.get("event_type") or ""
    res = payload.get("resource", {}) or {}
    order_id = res.get("id") or res.get("supplementary_data", {}).get("related_ids", {}).get("order_id")
    with get_conn() as conn:
        p = None
        if order_id:
            p = conn.execute(
                "SELECT * FROM payments WHERE (pay_no=? OR channel_txn_id=?) AND channel='paypal'",
                (order_id, order_id)).fetchone()
        custom_id = (res.get("custom_id")
                     or res.get("purchase_units", [{}])[0].get("custom_id")
                     if isinstance(res.get("purchase_units"), list) else None)
        if not p and custom_id:
            p = conn.execute("SELECT * FROM payments WHERE pay_no=?", (custom_id,)).fetchone()
        if not p:
            return {"verified": False, "reason": "no linked payment"}
        if p["status"] == "paid":
            return {"verified": True, "skipped": "already paid"}
        capture_id = res.get("id") or ("WEB" + uuid.uuid4().hex[:14].upper())
        settled = _settle_payment_success(conn, p["pay_no"], channel_txn_id=capture_id,
                                          raw_callback={"event_type": evt, **payload})
    return {"verified": True, "event": evt, "settled": settled}


@router.get("/paypal-confirm")
def paypal_quick_confirm(pay_no: str):
    """测试接口：一键模拟PayPal官方回调完成支付（方便前端/测试用）"""
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE pay_no=? AND channel='paypal'", (pay_no,)).fetchone()
        if not p:
            raise HTTPException(404, "PayPal支付单不存在")
        txn = p["channel_txn_id"] or _paypal_order_id()
        cap = "8FT" + "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", k=14))
        settled = _settle_payment_success(conn, pay_no, channel_txn_id=cap,
                                          raw_callback={"event_type": "PAYMENT.CAPTURE.COMPLETED",
                                                        "order_id": txn, "capture_id": cap,
                                                        "payer": "demo-buyer@sandbox.paypal.com"})
    return {"code": 200, "message": "✓ PayPal 支付确认成功", "data": settled}


# ============= USDT：链上通知/查询/快捷确认 =============
@router.post("/usdt/notify")
def usdt_chain_notify(body: UsdtNotifyReq):
    """模拟 USDT 链上到账回调（由第三方 USDT 网关或自建监听节点调用）：
       按 network+to_address+amount 匹配唯一未支付订单，到账即自动部署"""
    with get_conn() as conn:
        # 1) 先按 pay_no 精确找
        p = None
        if body.pay_no:
            p = conn.execute("SELECT * FROM payments WHERE pay_no=? AND channel='usdt'",
                             (body.pay_no,)).fetchone()
        # 2) 按钱包地址+精确金额匹配（生产：再校验 txid 重复入账）
        if not p:
            wallet = _sys_cfg(conn, "usdt_wallet_address")
            cny_rate = float(_sys_cfg(conn, "usdt_cny_usd_rate", "7.25"))
            # 金额允许 ±0.0001 的 float 误差
            rows = conn.execute(
                "SELECT * FROM payments WHERE channel='usdt' AND status='pending' "
                "AND CAST(remark AS TEXT) LIKE ? "
                "AND ABS(CAST(SUBSTR(remark, INSTR(remark,': ')+2, "
                "  INSTR(remark,' USDT') - INSTR(remark,': ')-2) AS REAL) - ?) < 0.001",
                (f"%{wallet}%", float(body.amount)),
            ).fetchall()
            if rows:
                p = rows[0]
        if not p:
            return {"code": 404, "message": "未匹配到待支付订单", "data": None}
        # 校验 txid 唯一性
        existing = conn.execute("SELECT id FROM payments WHERE channel_txn_id=?",
                                (body.txid,)).fetchone()
        if existing and existing["id"] != p["id"]:
            return {"code": 409, "message": "TXID 重复，已被其他订单占用", "data": {"txid": body.txid}}
        settled = _settle_payment_success(
            conn, p["pay_no"], channel_txn_id=body.txid,
            raw_callback={
                "txid": body.txid, "network": body.network,
                "amount": body.amount, "from": body.from_address, "to": body.to_address,
                "confirmations": body.confirmations,
            })
    return {"code": 200, "message": "USDT 到账成功，已触发部署", "data": settled}


@router.get("/usdt/check")
def usdt_check_status(pay_no: str, user=Depends(get_current_user)):
    """前端轮询：获取USDT订单支付状态+当前最新区块确认"""
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE pay_no=? AND user_id=?",
                         (pay_no, user["id"])).fetchone()
        if not p:
            raise HTTPException(404, "支付单不存在")
        order = conn.execute("SELECT status,order_no,deploy_status FROM orders WHERE id=?",
                             (p["order_id"],)).fetchone()
        raw = {}
        try:
            raw = json.loads(p["raw_callback"] or "{}") if p["raw_callback"] else {}
        except Exception:
            raw = {}
        return {"code": 200, "message": "ok", "data": {
            "pay_no": pay_no,
            "status": p["status"],  # pending / paid / expired
            "order_status": order["status"] if order else None,
            "deploy_status": order["deploy_status"] if order else None,
            "channel_txn_id": p["channel_txn_id"],
            "confirmations": raw.get("confirmations"),
            "txid": raw.get("txid"),
            "paid_at": p["paid_at"],
        }}


@router.get("/usdt-confirm")
def usdt_quick_confirm(pay_no: str, txid: Optional[str] = None, amount: Optional[float] = None):
    """测试接口：一键模拟USDT到账通知（方便前端自测）"""
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE pay_no=? AND channel='usdt'", (pay_no,)).fetchone()
        if not p:
            raise HTTPException(404, "USDT支付单不存在")
        # 如果没传金额，从 remark 里解析精确金额
        amt = amount
        if amt is None:
            try:
                rmk = p["remark"] or ""
                s = rmk.index(": ") + 2
                e = rmk.index(" USDT")
                amt = float(rmk[s:e])
            except Exception:
                amt = round(float(p["amount"]) / 7.25, 8)
        settled = _settle_payment_success(
            conn, pay_no,
            channel_txn_id=txid or _usdt_txid(),
            raw_callback={
                "txid": txid or _usdt_txid(), "network": "TRC20",
                "amount": amt, "to": _sys_cfg(conn, "usdt_wallet_address"),
                "confirmations": int(_sys_cfg(conn, "usdt_min_confirm", "1")),
            })
    return {"code": 200, "message": "✓ USDT 模拟到账成功", "data": settled}


# ============= 列表 / 详情 =============
@router.get("")
@router.get("/list")
def payment_list(
    page: int = 1, pageSize: int = 20,
    status: Optional[str] = None, channel: Optional[str] = None,
    all: Optional[str] = None,
    user=Depends(require_permission("payment:view")),
):
    """用户默认只看自己；超级管理员传 all=1 查看所有支付单"""
    with get_conn() as conn:
        q, params = [], []
        uid = scope_uid(user, all)
        if uid is not None:
            q.append("user_id=?")
            params.append(uid)
        if status:
            q.append("status=?"); params.append(status)
        if channel:
            q.append("channel=?"); params.append(channel)
        wc = ("WHERE " + " AND ".join(q)) if q else ""
        total = conn.execute(f"SELECT COUNT(*) c FROM payments {wc}", params).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM payments {wc} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    return {"code": 200, "message": "ok",
            "data": {"items": [dict(r) for r in rows], "total": total, "page": page, "pageSize": pageSize}}


@router.get("/{pay_no}")
def payment_detail(pay_no: str, user=Depends(get_current_user)):
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM payments WHERE pay_no=? AND user_id=?", (pay_no, user["id"])).fetchone()
        if not p:
            raise HTTPException(404, "支付单不存在")
        d = dict(p)
        try:
            d["raw_callback_json"] = json.loads(d["raw_callback"] or "{}") if d.get("raw_callback") else None
        except Exception:
            d["raw_callback_json"] = None
        return {"code": 200, "message": "ok", "data": d}
