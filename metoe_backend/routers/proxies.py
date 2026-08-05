import random, time
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Query, Request
from pydantic import BaseModel

from core.database import get_conn
from core.security import get_current_user, require_permission
from core.audit import write_audit

router = APIRouter(prefix="/proxies", tags=["接入实例 / 访问入口列表"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


COUNTRY_TREE = [
    {"group": "热门地区", "items": [
        {"code": "US", "name": "美国", "flag": "🇺🇸", "stock": 12800, "priceBase": 29},
        {"code": "JP", "name": "日本", "flag": "🇯🇵", "stock": 8400, "priceBase": 32},
        {"code": "GB", "name": "英国", "flag": "🇬🇧", "stock": 6200, "priceBase": 31},
        {"code": "DE", "name": "德国", "flag": "🇩🇪", "stock": 5600, "priceBase": 30},
        {"code": "KR", "name": "韩国", "flag": "🇰🇷", "stock": 4800, "priceBase": 34},
        {"code": "SG", "name": "新加坡", "flag": "🇸🇬", "stock": 3900, "priceBase": 33},
    ]},
    {"group": "美洲", "items": [
        {"code": "US", "name": "美国", "flag": "🇺🇸", "stock": 12800, "priceBase": 29},
        {"code": "CA", "name": "加拿大", "flag": "🇨🇦", "stock": 3200, "priceBase": 30},
        {"code": "BR", "name": "巴西", "flag": "🇧🇷", "stock": 2100, "priceBase": 36},
        {"code": "MX", "name": "墨西哥", "flag": "🇲🇽", "stock": 1800, "priceBase": 35},
    ]},
    {"group": "欧洲", "items": [
        {"code": "GB", "name": "英国", "flag": "🇬🇧", "stock": 6200, "priceBase": 31},
        {"code": "DE", "name": "德国", "flag": "🇩🇪", "stock": 5600, "priceBase": 30},
        {"code": "FR", "name": "法国", "flag": "🇫🇷", "stock": 4200, "priceBase": 31},
        {"code": "IT", "name": "意大利", "flag": "🇮🇹", "stock": 2800, "priceBase": 32},
        {"code": "ES", "name": "西班牙", "flag": "🇪🇸", "stock": 2500, "priceBase": 32},
        {"code": "NL", "name": "荷兰", "flag": "🇳🇱", "stock": 3100, "priceBase": 31},
    ]},
    {"group": "亚太", "items": [
        {"code": "JP", "name": "日本", "flag": "🇯🇵", "stock": 8400, "priceBase": 32},
        {"code": "KR", "name": "韩国", "flag": "🇰🇷", "stock": 4800, "priceBase": 34},
        {"code": "SG", "name": "新加坡", "flag": "🇸🇬", "stock": 3900, "priceBase": 33},
        {"code": "HK", "name": "香港", "flag": "🇭🇰", "stock": 2100, "priceBase": 38},
        {"code": "TW", "name": "台湾", "flag": "🇹🇼", "stock": 1900, "priceBase": 37},
        {"code": "IN", "name": "印度", "flag": "🇮🇳", "stock": 1700, "priceBase": 26},
    ]},
]


@router.get("/country-tree")
def country_tree(user=Depends(get_current_user)):
    return ok(COUNTRY_TREE)


@router.get("/prices")
def prices(category: str = "ISP", user=Depends(get_current_user)):
    factor = 0.55 if category == "DC" else 1.8 if category == "MOBILE" else 1.0
    plans = [
        {"key": "basic", "name": "入门版", "price": round(59 * factor), "unit": "月", "count": 1, "traffic": 50, "threads": 50},
        {"key": "standard", "name": "标准版", "price": round(149 * factor), "unit": "月", "count": 5, "traffic": 200, "threads": 200, "recommended": True},
        {"key": "pro", "name": "专业版", "price": round(299 * factor), "unit": "月", "count": 10, "traffic": 500, "threads": 500},
        {"key": "corp", "name": "企业版", "price": round(1299 * factor), "unit": "月", "count": 50, "traffic": 2000, "threads": 2000},
    ]
    return ok({"plans": plans, "category": category, "factor": factor})


@router.get("")
def proxies_list(
    page: int = 1, pageSize: int = 20,
    type: Optional[str] = None, country: Optional[str] = None,
    status: Optional[str] = None, keyword: Optional[str] = None,
    all: Optional[str] = None,
    user=Depends(require_permission("proxies:view")),
):
    uid = None if (all == "1" and user["is_super_admin"]) else user["id"]
    wh, params = [], []
    if uid is not None:
        wh.append("user_id = ?")
        params.append(uid)
    if type:
        wh.append("type = ?"); params.append(type)
    if country:
        wh.append("country_code = ?"); params.append(country)
    if status:
        wh.append("status = ?"); params.append(status)
    if keyword:
        wh.append("(ip LIKE ? OR username LIKE ?)")
        params.extend([f"%{keyword}%", f"%{keyword}%"])
    where = ("WHERE " + " AND ".join(wh)) if wh else ""

    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM proxies {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM proxies {where} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()

    list_ = []
    for r in rows:
        r = dict(r)
        list_.append({
            "id": r["id"], "country": r["country_name"],
            "countryFlag": r["country_flag"], "countryCode": r["country_code"],
            "type": "DC" if r["category"] == "DC" else ("MOBILE" if r["category"] == "MOBILE" else "ISP"),
            "category": r["category"], "protocol": r["protocol"],
            "ip": r["ip"], "port": r["port"], "username": r["username"], "password": r["password"],
            "trafficUsed": r["traffic_used"], "trafficTotal": r["traffic_total"],
            "expireAt": r["expire_at"], "status": r["status"], "createdAt": r["created_at"],
            "serverId": r.get("server_id"), "deployTaskId": r.get("deploy_task_id"),
            "vpnUrl": r.get("vpn_url"), "vpnQrCode": r.get("vpn_qr_code"),
            "entryUrl": r.get("vpn_url"), "qrCode": r.get("vpn_qr_code"),
            "vpnConfigPath": r.get("vpn_config_path"), "vpnConfigContent": r.get("vpn_config_content"),
            "orderId": r.get("order_id"),
        })
    return ok({"total": total, "page": page, "pageSize": pageSize, "list": list_})


@router.get("/{id_}")
def proxy_detail(id_: int, user=Depends(require_permission("nodes:view"))):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM proxies WHERE id=?", (id_,)).fetchone()
    if not r:
        return fail("记录不存在", 404)
    if not user["is_super_admin"] and r["user_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="无权限")
    return ok(dict(r))


@router.put("/{id_}")
def proxy_update(
    id_: int, body: dict,
    user=Depends(require_permission("nodes:manage")),
):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM proxies WHERE id=?", (id_,)).fetchone()
        if not r:
            return fail("记录不存在", 404)
        if not user["is_super_admin"] and r["user_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="无权限")
        conn.execute(
            """UPDATE proxies SET
                 status=COALESCE(?,status), expire_at=COALESCE(?,expire_at),
                 traffic_total=COALESCE(?,traffic_total), auth_type=COALESCE(?,auth_type),
                 whitelist_ips=COALESCE(?,whitelist_ips),
                 updated_at=datetime('now','localtime')
               WHERE id=?""",
            (
                body.get("status"), body.get("expire_at"), body.get("traffic_total"),
                body.get("auth_type"), body.get("whitelist_ips"), id_,
            ),
        )
    return ok(None, "已更新")


@router.delete("/{id_}")
def proxy_delete(id_: int, request: Request, user=Depends(get_current_user)):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM proxies WHERE id=?", (id_,)).fetchone()
        if not r:
            return fail("记录不存在", 404)
        if not user["is_super_admin"] and r["user_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="无权限")
        info = {"id": r["id"], "ip": r.get("ip"), "country": r.get("country_code"),
                "status": r.get("status"), "server_id": r.get("server_id")}
        conn.execute("DELETE FROM proxies WHERE id=?", (id_,))
    write_audit(
        user, "resource:delete",
        resource_type="proxy", resource_id=str(id_),
        old=info, new=None,
        summary=f"删除接入实例 #{id_}（{r.get('country_code') or '?'} / {r.get('ip') or '-'}）",
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return ok(None, "已删除")


class BatchReq(BaseModel):
    ids: List[int] = []


@router.post("/batch/{action}")
def batch(action: str, body: BatchReq, request: Request, user=Depends(get_current_user)):
    if not body.ids:
        return fail("请选择要操作的记录")
    placeholders = ",".join("?" * len(body.ids))
    uid_clause = "" if user["is_super_admin"] else " AND user_id = ?"
    params = list(body.ids) + ([] if user["is_super_admin"] else [user["id"]])
    action_label = {"renew": "批量续费", "pause": "批量暂停", "resume": "批量恢复", "delete": "批量删除"}.get(action, f"批量{action}")
    old_snapshot = None
    with get_conn() as conn2:
        rows = conn2.execute(
            f"SELECT id, ip, country_code, status FROM proxies WHERE id IN ({placeholders}){uid_clause}",
            params,
        ).fetchall()
        old_snapshot = [dict(r) for r in rows]
    if action == "renew":
        try:
            write_audit(user, "resource:batch", resource_type="proxy", resource_id=",".join(str(i) for i in body.ids),
                        old=old_snapshot, new=None,
                        summary=f"{action_label} #{len(body.ids)} 条接入实例 → 生成续费订单（待支付）",
                        ip=request.client.host if request.client else None,
                        ua=request.headers.get("user-agent"))
        except Exception:
            pass
        return ok({"count": len(body.ids)}, "续费订单待支付")
    if action == "pause":
        sql = f"UPDATE proxies SET status='paused', updated_at=datetime('now','localtime') WHERE id IN ({placeholders}){uid_clause}"
    elif action == "resume":
        sql = f"UPDATE proxies SET status='active', updated_at=datetime('now','localtime') WHERE id IN ({placeholders}){uid_clause}"
    elif action == "delete":
        sql = f"DELETE FROM proxies WHERE id IN ({placeholders}){uid_clause}"
    else:
        return fail("未知操作")
    with get_conn() as conn:
        cur = conn.execute(sql, params)
    try:
        write_audit(user, "resource:batch" if action != "delete" else "resource:delete",
                    resource_type="proxy", resource_id=",".join(str(i) for i in body.ids),
                    old=old_snapshot,
                    new=(None if action == "delete" else {"to_status": "paused" if action == "pause" else "active"}),
                    summary=f"{action_label} #{len(body.ids)} 条接入实例 · 影响 {cur.rowcount} 行",
                    ip=request.client.host if request.client else None,
                    ua=request.headers.get("user-agent"))
    except Exception:
        pass
    return ok({"count": cur.rowcount}, "操作完成")


class BuyReq(BaseModel):
    category: str = "ISP"
    country: str
    countryName: Optional[str] = None
    countryFlag: Optional[str] = None
    city: Optional[str] = None
    qty: int = 1
    period: str = "1m"
    plan: str = "standard"
    amount: float = 0
    discount: float = 0
    total: float = 0
    cpu: Optional[int] = None
    ram: Optional[int] = None
    disk: Optional[int] = None
    os: Optional[str] = None
    bandwidth: Optional[int] = None
    traffic: Optional[float] = None
    usage: Optional[str] = None
    usagePurpose: Optional[str] = None
    protocol: Optional[str] = None
    encryptMode: Optional[str] = None
    udp: Optional[bool] = None
    bwMode: Optional[str] = None
    dedicatedEntry: Optional[bool] = None
    authMode: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    whitelistIps: Optional[str] = None
    whitelist: Optional[str] = None
    payMethod: Optional[str] = None
    autoRenew: Optional[bool] = None
    protocols: List[str] = ["HTTP", "SOCKS5"]
    auth: str = "pwd"


@router.post("/buy")
def buy(req: BuyReq, request: Request, user=Depends(require_permission("orders:create"))):
    """下单购买接口：创建 pending 订单（不扣余额，不直接分配资源）。
    后续用户在订单/支付页选择支付方式，支付成功后系统自动调用
    Lisa主机API购买服务器 → 执行初始化脚本 → 生成访问入口并保存。"""
    if not req.country:
        return fail("请选择地区")
    if req.qty < 1:
        return fail("数量错误")
    period_days = {"1m": 30, "3m": 90, "6m": 180, "1y": 365}.get(req.period, 30)
    period_txt = {"1m":"1个月","3m":"3个月","6m":"6个月","1y":"1年"}.get(req.period,"1个月")
    usage_txt = {"web":"网站托管","ecom":"跨境电商","office":"企业办公","dev":"开发测试","data":"数据运算","game":"游戏应用"}.get(req.usage or "","")
    config_txt = f"{req.cpu or 2}核/{req.ram or 2}G/{req.disk or 50}G/{req.bandwidth or 30}Mbps"
    product = f"{req.countryName or req.country}{'·'+usage_txt if usage_txt else ''}·{config_txt}·×{req.qty}台·{period_txt}"
    order_no = f"PO{int(time.time()*1000)}{random.randint(1000,9999)}"

    with get_conn() as conn:
        order_id = conn.execute(
            """INSERT INTO orders
                 (order_no, user_id, product, category, country_code, country_name, country_flag,
                  qty, plan, period, amount, discount, total, pay_method, status, deploy_status, remark)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?, NULL, 'pending', 'pending', ?)""",
            (order_no, user["id"], product, req.usage or req.category, req.country,
             req.countryName, req.countryFlag, req.qty, req.plan,
             req.period, float(req.amount), float(req.discount), float(req.total),
             f"CPU={req.cpu or 2};RAM={req.ram or 2}GB;DISK={req.disk or 50}GB;OS={req.os or 'Ubuntu 22.04'};BW={req.bandwidth or 30}Mbps;TRAFFIC={req.traffic or 0};USAGE={req.usage or ''};USER={req.username or 'root'};PWD={'***' if req.password else ''}"),
        ).lastrowid
    try:
        write_audit(
            user, "order:create",
            resource_type="order", resource_id=str(order_id),
            new={
                "order_no": order_no, "country": req.country, "usage": req.usage,
                "qty": req.qty, "period": req.period,
                "amount": float(req.amount), "discount": float(req.discount),
                "total": float(req.total), "plan": req.plan,
            },
            summary=f"创建订单 #{order_no}：{product}，应付 ¥{float(req.total):.2f}",
            ip=request.client.host if request.client else None,
            ua=request.headers.get("user-agent"),
        )
    except Exception:
        pass
    return ok({
        "orderNo": order_no, "orderId": order_id,
        "product": product, "total": f"{float(req.total):.2f}",
        "needPay": True, "periodDays": period_days,
    }, f"订单已创建，待支付金额 ¥{float(req.total):.2f}")


@router.post("/{id_}/redeploy")
def proxy_redeploy(id_: int, request: Request, user=Depends(require_permission("deploy:run"))):
    """重新部署：复用已有服务器，重新执行初始化脚本"""
    from services.pipeline import run_deploy_only
    with get_conn() as conn:
        p = conn.execute("SELECT * FROM proxies WHERE id=?", (id_,)).fetchone()
        if not p:
            return fail("节点不存在", 404)
        pd = dict(p)
        if pd["user_id"] != user["id"] and not user.get("is_super_admin"):
            return fail("无权操作", 403)
        if not pd.get("server_id"):
            return fail("该节点没有关联服务器，无法重部署")
        order = conn.execute("SELECT * FROM orders WHERE id=?", (pd["order_id"],)).fetchone()
        if not order:
            return fail("订单丢失，无法重部署")
        old_info = {"status": pd.get("status"), "server_id": pd.get("server_id"),
                    "ip": pd.get("ip"), "country": pd.get("country_code")}
        result = run_deploy_only(conn, dict(order), dict(user), server_id=pd["server_id"])
    write_audit(
        user, "resource:redeploy",
        resource_type="proxy", resource_id=str(id_),
        old=old_info, new={"deploy_id": result.get("deploy_id"), "task_no": result.get("task_no")},
        summary=f"重部署接入实例 #{id_}（{pd.get('country_code') or '?'}）→ task#{result.get('task_no') or '-'}",
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return ok(result, "重部署任务已启动，约30-60秒完成")
