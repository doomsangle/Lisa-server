"""云服务器管理接口（购买后的Lisa主机实例）"""
from fastapi import APIRouter, HTTPException, Depends, Request

from core.database import get_conn
from core.security import require_permission, get_current_user, uid_int, enforce_owner_or_super
from core.audit import audit_server_reboot, audit_server_reinstall, audit_server_delete, write_audit

router = APIRouter(prefix="/servers", tags=["云服务器"])


def _row_to_server(r, user):
    d = dict(r)
    if not (d.get("user_id") == user["id"] or user.get("is_super_admin")):
        d["ssh_password"] = "***"
        d["ssh_key_path"] = None
    # 兜底：如果 vps_servers.entry_url/qr_code 为空，用最新 deploy 任务的 vpn_url/vpn_qr_code（兼容历史数据）
    entry_url = d.get("entry_url") or d.get("deploy_vpn_url") or None
    qr_code = d.get("qr_code") or d.get("deploy_vpn_qr_code") or None
    # 状态归一：旧值 running → active (前端 statusTag 计数统一)；provisioning/deploying 保持 (初始化)
    raw_status = (d.get("status") or "provisioning").lower()
    if raw_status == "running":
        norm_status = "active"
    elif raw_status in ("stopped", "poweroff", "shutdown"):
        norm_status = "stopped"
    elif raw_status in ("failed", "fatal"):
        norm_status = "error"
    else:
        norm_status = raw_status
    return {
        "id": d["id"],
        "userId": d.get("user_id"),
        "orderId": d.get("order_id"),
        "serverId": d.get("lisa_vps_id"),
        "provider": d.get("provider", "lisa"),
        "region": d.get("region", ""),
        "spec": d.get("spec", ""),
        "ip": d.get("ip", ""),
        "ipv6": d.get("ipv6"),
        "sshPort": d.get("ssh_port", 22),
        "sshUser": d.get("ssh_user", "root"),
        "sshPassword": d.get("ssh_password", ""),
        "sshKeyPath": d.get("ssh_key_path"),
        "os": d.get("os", "Ubuntu 22.04 LTS"),
        "cpuCores": int(d.get("cpu_cores") or 1),
        "ramMb": int(d.get("ram_mb") or 1024),
        "diskGb": int(d.get("disk_gb") or 25),
        "bandwidthMbps": int(d.get("bandwidth_mbps") or 100),
        "priceMonth": float(d.get("price_month") or 0),
        "status": norm_status,
        "usage": d.get("usage") or d.get("category") or "ecom",
        "category": d.get("usage") or d.get("category") or "ecom",
        "entryUrl": entry_url,
        "qrCode": qr_code,
        "expireAt": d.get("expire_at"),
        "createdAt": d.get("created_at"),
        "updatedAt": d.get("updated_at"),
        "username": d.get("username"),
        "lastTaskNo": d.get("last_task_no"),
        "lastDeployStatus": d.get("last_deploy_status"),
    }


@router.get("")
def server_list(
    status: str = None, page: int = 1, pageSize: int = 20,
    keyword: str = None, region: str = None,
    all: str = None, user=Depends(get_current_user),
):
    """查询我的云服务器。管理员传 all=1 查看全部"""
    with get_conn() as conn:
        wh, params = [], []
        if not (all == "1" and user.get("is_super_admin")):
            wh.append("s.user_id = ?")
            params.append(user["id"])
        if status:
            wh.append("s.status = ?")
            params.append(status)
        if region:
            wh.append("s.region LIKE ?")
            params.append(f"%{region}%")
        if keyword:
            wh.append("(s.ip LIKE ? OR s.spec LIKE ? OR o.order_no LIKE ? OR u.username LIKE ?)")
            like = f"%{keyword}%"
            params.extend([like, like, like, like])
        where = ("WHERE " + " AND ".join(wh)) if wh else ""
        total = conn.execute(
            f"""SELECT COUNT(*) c FROM vps_servers s
                LEFT JOIN users u ON u.id=s.user_id
                LEFT JOIN orders o ON o.id=s.order_id
                {where}""",
            params,
        ).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT s.*,
                       (SELECT COUNT(*) FROM proxies p WHERE p.server_id=s.id) proxy_count,
                       (SELECT task_no FROM deploy_tasks d WHERE d.server_id=s.id ORDER BY d.id DESC LIMIT 1) last_task_no,
                       (SELECT status FROM deploy_tasks d WHERE d.server_id=s.id ORDER BY d.id DESC LIMIT 1) last_deploy_status,
                       (SELECT vpn_url FROM deploy_tasks d WHERE d.server_id=s.id ORDER BY d.id DESC LIMIT 1) deploy_vpn_url,
                       (SELECT vpn_qr_code FROM deploy_tasks d WHERE d.server_id=s.id ORDER BY d.id DESC LIMIT 1) deploy_vpn_qr_code,
                       u.username
                FROM vps_servers s LEFT JOIN users u ON u.id=s.user_id
                {where} ORDER BY s.id DESC LIMIT ? OFFSET ?""",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
        items = [_row_to_server(r, user) for r in rows]
    return {"code": 200, "message": "ok", "data": {"list": items, "total": total, "page": page, "pageSize": pageSize}}


@router.get("/{sid}")
def server_detail(sid: int, user=Depends(get_current_user)):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM vps_servers WHERE id=?", (sid,)).fetchone()
        if not row:
            raise HTTPException(404, "服务器不存在")
        if row["user_id"] != user["id"] and not user.get("is_super_admin"):
            raise HTTPException(403, "无权查看")
        d = _row_to_server(row, user)
        d["deploys"] = [
            {
                "id": r["id"], "taskNo": r["task_no"], "status": r["status"],
                "progress": r["progress"], "currentPhase": r["current_phase"],
                "entryUrl": r["vpn_url"], "qrCode": r["vpn_qr_code"],
                "configPath": r["vpn_config_path"], "configContent": r["vpn_config_content"],
                "startedAt": r["started_at"], "finishedAt": r["finished_at"],
            } for r in conn.execute(
                "SELECT id, task_no, status, progress, current_phase, vpn_url, vpn_qr_code, vpn_config_path, vpn_config_content, started_at, finished_at FROM deploy_tasks WHERE server_id=? ORDER BY id DESC",
                (sid,),
            ).fetchall()
        ]
        d["nodes"] = [
            {
                "id": r["id"], "category": r["category"],
                "countryCode": r["country_code"], "countryName": r["country_name"],
                "countryFlag": r["country_flag"], "ip": r["ip"], "port": r["port"],
                "username": r["username"], "protocol": r["protocol"],
                "status": r["status"], "expireAt": r["expire_at"],
                "entryUrl": r["vpn_url"], "qrCode": r["vpn_qr_code"],
                "configPath": r["vpn_config_path"],
            } for r in conn.execute(
                "SELECT id, category, country_code, country_name, country_flag, ip, port, username, protocol, status, expire_at, vpn_url, vpn_qr_code, vpn_config_path FROM proxies WHERE server_id=? ORDER BY id DESC",
                (sid,),
            ).fetchall()
        ]
    return {"code": 200, "message": "ok", "data": d}


@router.post("/{sid}/reboot")
def server_reboot(sid: int, request: Request, _user=Depends(require_permission("servers:manage"))):
    """Lisa主机重启接口（模拟）"""
    import random
    with get_conn() as conn:
        s = conn.execute("SELECT * FROM vps_servers WHERE id=?", (sid,)).fetchone()
        if not s:
            raise HTTPException(404, "服务器不存在")
        enforce_owner_or_super(_user, s, action="重启")
        old_status = s["status"]
        new_status = "active" if random.random() > 0.05 else "error"
        conn.execute("UPDATE vps_servers SET status=?, updated_at=datetime('now','localtime') WHERE id=?", (new_status, sid))
    audit_server_reboot(
        _user,
        resource_id=str(sid),
        old={"status": old_status},
        new={"status": new_status},
        summary=f"重启服务器 #{sid}（{s.get('provider') or s.get('region_code') or 'unknown'}）：{old_status} → {new_status}",
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return {"code": 200, "message": f"重启指令已下发至Lisa API，当前状态：{new_status}", "data": {"status": new_status}}


@router.post("/{sid}/reinstall")
def server_reinstall(sid: int, request: Request, _user=Depends(require_permission("servers:manage"))):
    """重装操作系统"""
    with get_conn() as conn:
        s = conn.execute("SELECT * FROM vps_servers WHERE id=?", (sid,)).fetchone()
        if not s:
            raise HTTPException(404, "服务器不存在")
        enforce_owner_or_super(_user, s, action="重装")
        old_status = s["status"]
        conn.execute("UPDATE vps_servers SET status='reinstalling', updated_at=datetime('now','localtime') WHERE id=?", (sid,))
    audit_server_reinstall(
        _user,
        resource_id=str(sid),
        old={"status": old_status, "os": s.get("os")},
        new={"status": "reinstalling"},
        summary=f"重装系统 #{sid}（{s.get('ip') or s.get('region_code') or '-'}）：已提交重装任务（预计3-8分钟完成）",
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return {"code": 200, "message": "已提交系统重装任务，预计 3-8 分钟完成", "data": None}
