from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query, Request

from core.database import get_conn
from core.security import get_current_user, require_permission, require_role, scope_uid, enforce_owner_or_super
from core.audit import audit_order_status_change, audit_payment_success, write_audit

router = APIRouter(prefix="/orders", tags=["订单"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


@router.get("")
def orders_list(
    page: int = 1, pageSize: int = 20,
    status: Optional[str] = None, keyword: Optional[str] = None,
    all: Optional[str] = None,
    user=Depends(require_permission("orders:view")),
):
    uid = None if (all == "1" and user["is_super_admin"]) else user["id"]
    wh, params = [], []
    if uid is not None:
        wh.append("user_id = ?"); params.append(uid)
    if status:
        wh.append("status = ?"); params.append(status)
    if keyword:
        wh.append("(order_no LIKE ? OR product LIKE ?)")
        params.extend([f"%{keyword}%", f"%{keyword}%"])
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM orders {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM orders {where} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "id": rd["id"], "orderNo": rd["order_no"], "userId": rd["user_id"],
            "product": rd["product"], "category": rd["category"],
            "countryCode": rd["country_code"], "countryName": rd.get("country_name"),
            "countryFlag": rd.get("country_flag"),
            "qty": rd["qty"],
            "plan": rd["plan"], "period": rd["period"],
            "amount": f"{float(rd['amount']):.2f}",
            "discount": f"{float(rd['discount']):.2f}",
            "total": f"{float(rd['total']):.2f}",
            "payMethod": rd["pay_method"], "status": rd["status"],
            "paidAt": rd["paid_at"], "createdAt": rd["created_at"],
            "updatedAt": rd.get("updated_at"),
            "deployStatus": rd.get("deploy_status"),
            "lisaOrderId": rd.get("lisa_order_id"),
            "lisaProvider": rd.get("lisa_provider"),
            "lisaRegion": rd.get("lisa_region"),
            "remark": rd.get("remark"),
        })
    return ok({"total": total, "page": page, "pageSize": pageSize, "list": list_})


@router.get("/{order_no}")
def order_detail(order_no: str, user=Depends(get_current_user)):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM orders WHERE order_no=?", (order_no,)).fetchone()
        if not r:
            return fail("订单不存在", 404)
        if not user["is_super_admin"] and r["user_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="无权限")
        od = dict(r)
        data = {
            "id": od["id"], "orderNo": od["order_no"], "order_no": od["order_no"],
            "userId": od["user_id"], "product": od["product"],
            "category": od.get("category"),
            "countryCode": od.get("country_code"),
            "countryName": od.get("country_name"), "country_name": od.get("country_name"),
            "countryFlag": od.get("country_flag"),
            "qty": od.get("qty", 1), "plan": od.get("plan"), "period": od.get("period"),
            "amount": f"{float(od['amount']):.2f}",
            "discount": f"{float(od['discount']):.2f}",
            "total": f"{float(od['total']):.2f}",
            "payMethod": od.get("pay_method"), "status": od.get("status"),
            "paidAt": od.get("paid_at"), "paid_at": od.get("paid_at"),
            "createdAt": od.get("created_at"), "created_at": od.get("created_at"),
            "updatedAt": od.get("updated_at"),
            "deployStatus": od.get("deploy_status"), "deploy_status": od.get("deploy_status"),
            "lisaOrderId": od.get("lisa_order_id"), "lisa_order_id": od.get("lisa_order_id"),
            "lisaProvider": od.get("lisa_provider"), "lisa_provider": od.get("lisa_provider"),
            "lisaRegion": od.get("lisa_region"), "lisa_region": od.get("lisa_region"),
            "lisaSpec": od.get("lisa_spec"), "lisaSpec": od.get("lisa_spec"),
            "lisaPrice": od.get("lisa_price"),
            "remark": od.get("remark"),
        }
        # 关联节点列表
        proxies = conn.execute("SELECT * FROM proxies WHERE order_id=?", (r["id"],)).fetchall()
        data["nodes"] = []
        data["proxies"] = []
        for p in proxies:
            p = dict(p)
            item = {
                "id": p["id"], "category": p["category"],
                "countryCode": p["country_code"], "country": p["country_name"],
                "countryName": p["country_name"], "countryFlag": p["country_flag"],
                "ip": p["ip"], "port": p["port"],
                "username": p.get("username"), "password": p.get("password"),
                "protocol": p.get("protocol"), "status": p.get("status"),
                "expireAt": p.get("expire_at"),
                "entryUrl": p.get("vpn_url"), "vpnUrl": p.get("vpn_url"),
                "qrCode": p.get("vpn_qr_code"), "vpnQrCode": p.get("vpn_qr_code"),
                "configPath": p.get("vpn_config_path"), "vpnConfigPath": p.get("vpn_config_path"),
                "configContent": p.get("vpn_config_content"), "vpnConfigContent": p.get("vpn_config_content"),
                "trafficUsed": p.get("traffic_used"), "trafficTotal": p.get("traffic_total"),
            }
            data["nodes"].append(item)
            data["proxies"].append(item)
        # 关联服务器
        server = conn.execute("SELECT * FROM vps_servers WHERE order_id=? ORDER BY id DESC LIMIT 1", (r["id"],)).fetchone()
        if server:
            s = dict(server)
            server_data = {
                **s,
                "id": s["id"], "ip": s["ip"], "ipv6": s.get("ipv6"),
                "provider": s.get("provider"), "region": s.get("region"),
                "spec": s.get("spec"),
                "cpuCores": s.get("cpu_cores", 1), "cpu_cores": s.get("cpu_cores"),
                "ramMb": s.get("ram_mb", 1024), "ram_mb": s.get("ram_mb"),
                "diskGb": s.get("disk_gb", 25), "disk_gb": s.get("disk_gb"),
                "bandwidthMbps": s.get("bandwidth_mbps", 100), "bandwidth_mbps": s.get("bandwidth_mbps"),
                "sshPort": s.get("ssh_port", 22), "ssh_port": s.get("ssh_port"),
                "sshUser": s.get("ssh_user", "root"), "ssh_user": s.get("ssh_user"),
                "sshPassword": s.get("ssh_password"), "ssh_password": s.get("ssh_password"),
                "os": s.get("os"), "priceMonth": s.get("price_month"), "price_month": s.get("price_month"),
                "status": s.get("status"), "usage": s.get("usage"),
                "entryUrl": s.get("entry_url"), "qrCode": s.get("qr_code"),
                "expireAt": s.get("expire_at"), "expire_at": s.get("expire_at"),
            }
        else:
            server_data = None
        data["server"] = server_data
        # 关联部署任务
        deploy = conn.execute("SELECT * FROM deploy_tasks WHERE order_id=? ORDER BY id DESC LIMIT 1", (r["id"],)).fetchone()
        if deploy:
            dp = dict(deploy)
            deploy_data = {
                **dp,
                "id": dp["id"], "taskNo": dp["task_no"], "task_no": dp["task_no"],
                "status": dp.get("status"), "step": dp.get("step"),
                "totalSteps": dp.get("total_steps"), "progress": dp.get("progress"),
                "currentPhase": dp.get("current_phase"),
                "logsOutput": dp.get("log_text"), "logs_output": dp.get("log_text"),
                "entryUrl": dp.get("vpn_url"), "vpnUrl": dp.get("vpn_url"),
                "qrCode": dp.get("vpn_qr_code"), "vpnQrCode": dp.get("vpn_qr_code"),
                "configPath": dp.get("vpn_config_path"), "vpnConfigPath": dp.get("vpn_config_path"),
                "configContent": dp.get("vpn_config_content"), "vpnConfigContent": dp.get("vpn_config_content"),
                "startedAt": dp.get("started_at"), "started_at": dp.get("started_at"),
                "finishedAt": dp.get("finished_at"), "finished_at": dp.get("finished_at"),
                "errorMsg": dp.get("error_msg"),
            }
        else:
            deploy_data = None
        data["deploy"] = deploy_data
        # 支付记录
        payments = conn.execute("SELECT * FROM payments WHERE order_id=? ORDER BY id DESC", (r["id"],)).fetchall()
        data["payments"] = [
            {
                "id": p["id"], "payNo": p["pay_no"], "pay_no": p["pay_no"],
                "orderId": p["order_id"], "orderNo": p["order_no"],
                "userId": p["user_id"], "channel": p["channel"],
                "amount": p["amount"], "currency": p["currency"],
                "status": p["status"], "channelTxnId": p["channel_txn_id"],
                "paidAt": p["paid_at"], "paid_at": p["paid_at"],
                "rawCallback": p["raw_callback"], "remark": p["remark"],
                "createdAt": p["created_at"],
            }
            for p in (dict(row) for row in payments)
        ]
    return ok(data)


@router.post("/{order_no}/pay")
def order_pay(order_no: str, body: dict = {}, user=Depends(get_current_user)):
    """订单支付入口（兼容旧的前端路径），逻辑统一复用 payments router 共享实现
       支持渠道：balance / mock / alipay / wechat / usdt / paypal
    """
    channel = body.get("channel") or "balance"
    return_url = body.get("return_url")
    cancel_url = body.get("cancel_url")
    from routers.payments import _get_order, do_create_payment
    with get_conn() as conn:
        order = _get_order(conn, user, None, order_no)
        return do_create_payment(conn, order, user, channel,
                                 return_url=return_url, cancel_url=cancel_url)


@router.put("/{id_}/status")
def order_status(id_: int, body: dict, request: Request, user=Depends(require_permission("orders:manage"))):
    st = body.get("status")
    if st not in ["pending", "paid", "refunded", "cancelled"]:
        return fail("状态无效")
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM orders WHERE id=?", (id_,)).fetchone()
        if not row:
            return fail("订单不存在", 404)
        enforce_owner_or_super(user, row, action="修改订单")
        old_status = row["status"]
        conn.execute("UPDATE orders SET status=? WHERE id=?", (st, id_))
    audit_order_status_change(
        user,
        resource_type="order",
        resource_id=str(id_),
        old={"status": old_status, "order_no": row.get("order_no"), "total": row.get("total")},
        new={"status": st},
        summary=f"订单状态变更 #{id_}：{old_status} → {st}"
                + (f"（退款；总金额 ¥{float(row.get('total') or 0):.2f}）" if st == "refunded" else ""),
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return ok(None, "已更新")
