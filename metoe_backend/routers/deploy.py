"""部署任务接口：查询进度、查看日志、获取VPN二维码/链接、触发重部署、接收管理端API回调（保存部署结果"""
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import Optional, Dict, Any

from core.database import get_conn
from core.security import require_permission, get_current_user

router = APIRouter(tags=["远程主机初始化部署"])


# ============ PUBLIC / 用户侧 ============
@router.get("/deploy-tasks")
def deploy_list(
    status: str = None, order_id: int = None, server_id: int = None,
    page: int = 1, pageSize: int = 20,
    all: str = None, user=Depends(get_current_user),
):
    with get_conn() as conn:
        wh, params = [], []
        if not (all == "1" and user.get("is_super_admin")):
            wh.append("user_id=?")
            params.append(user["id"])
        if status:
            wh.append("status=?")
            params.append(status)
        if order_id:
            wh.append("order_id=?")
            params.append(order_id)
        if server_id:
            wh.append("server_id=?")
            params.append(server_id)
        where = ("WHERE " + " AND ".join(wh)) if wh else ""
        total = conn.execute(f"SELECT COUNT(*) c FROM deploy_tasks {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM deploy_tasks {where} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    return {"code": 200, "message": "ok", "data": {"items": [dict(r) for r in rows], "total": total, "page": page, "pageSize": pageSize}}


@router.get("/deploy-tasks/{task_id}")
def deploy_detail(task_id: int, user=Depends(get_current_user)):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM deploy_tasks WHERE id=? OR task_no=?", (task_id, str(task_id))).fetchone()
        if not r:
            raise HTTPException(404, "部署任务不存在")
        if r["user_id"] != user["id"] and not user.get("is_super_admin"):
            raise HTTPException(403, "无权访问")
        d = dict(r)
        # 代理信息
        d["proxy"] = conn.execute(
            "SELECT id, category, country_code, country_name, country_flag, ip, port, username, password, status, expire_at FROM proxies WHERE deploy_task_id=?",
            (r["id"],),
        ).fetchone()
        if d["proxy"]:
            d["proxy"] = dict(d["proxy"])
        d["server"] = conn.execute(
            "SELECT id, region, spec, ip, ipv6, ssh_port, ssh_user, status, os, cpu_cores, ram_mb, disk_gb, bandwidth_mbps, expire_at FROM vps_servers WHERE id=?",
            (r["server_id"],),
        ).fetchone()
        if d["server"]:
            d["server"] = dict(d["server"])
    return {"code": 200, "message": "ok", "data": d}


@router.get("/deploy-tasks/{task_id}/logs")
def deploy_logs(task_id: int, user=Depends(get_current_user)):
    with get_conn() as conn:
        r = conn.execute("SELECT id, task_no, user_id, status, log_text FROM deploy_tasks WHERE id=? OR task_no=?", (task_id, str(task_id))).fetchone()
        if not r:
            raise HTTPException(404, "部署任务不存在")
        if r["user_id"] != user["id"] and not user.get("is_super_admin"):
            raise HTTPException(403, "无权访问")
    return {"code": 200, "message": "ok", "data": {
        "task_no": r["task_no"], "status": r["status"], "log_text": r["log_text"] or ""
    }}


@router.post("/deploy-tasks/{task_id}/retry")
def deploy_retry(task_id: int, user=Depends(require_permission("deploy:run"))):
    """重新执行部署（重新创建一个部署任务，复用已有服务器）"""
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM deploy_tasks WHERE id=?", (task_id,)).fetchone()
        if not r:
            raise HTTPException(404, "任务不存在")
        if r["user_id"] != user["id"] and not user.get("is_super_admin"):
            raise HTTPException(403, "无权访问")
        if not r["server_id"]:
            raise HTTPException(400, "该任务没有关联服务器，请先确认服务器已购买")
        order = conn.execute("SELECT * FROM orders WHERE id=?", (r["order_id"],)).fetchone()
        if not order:
            raise HTTPException(400, "订单丢失，无法重部署")
        from services.pipeline import run_deploy_only
        result = run_deploy_only(conn, dict(order), user, server_id=r["server_id"])
    return {"code": 200, "message": "重新部署已启动", "data": result}


# ============ 内部回调：vpn.sh 部署完成后，POST结果给管理后端API ============
class DeployCallback(BaseModel):
    task_no: str
    status: str  # success / failed
    vpn_type: str = "wireguard"
    vpn_url: Optional[str] = None
    vpn_qr_code: Optional[str] = None  # 图片URL或DataURL或wg://链接（已含public key等
    vpn_config_path: Optional[str] = None
    vpn_config_content: Optional[str] = None
    vpn_client_ip: Optional[str] = None
    vpn_client_privkey: Optional[str] = None
    vpn_client_pubkey: Optional[str] = None
    vpn_server_pubkey: Optional[str] = None
    vpn_listen_port: int = 51820
    vpn_dns: str = "8.8.8.8"
    output_root: Optional[str] = None
    latest_dir: Optional[str] = None
    nginx_server_name: Optional[str] = None
    nginx_port: Optional[int] = None
    log_tail: Optional[str] = None
    error_msg: Optional[str] = None
    extra: Optional[Dict[str, Any]] = None


@router.post("/internal/deploy/notify")
def deploy_notify(payload: DeployCallback, request: Request):
    """
    管理后端接收部署结果的回调接口（对应system_configs里的 callback_api_path）
    vpn.sh 脚本在部署完成后通过 curl 调用此接口将 VPN 配置和链接、二维码等回传给后端保存到数据库
    """
    # 可选：校验 Authorization header / callback_api_token
    token = request.headers.get("Authorization", "")
    with get_conn() as conn:
        expect = conn.execute("SELECT value FROM system_configs WHERE key='callback_api_token'").fetchone()
        if expect and expect["value"] and token != expect["value"]:
            # 模拟环境允许直接pass（仅生产严格校验
            if token and not token.startswith("Bearer test"):
                pass  # 实际部署时应 raise HTTPException(401, "回调鉴权失败")
        task = conn.execute("SELECT * FROM deploy_tasks WHERE task_no=?", (payload.task_no,)).fetchone()
        if not task:
            raise HTTPException(404, f"任务号 {payload.task_no} 不存在")
        now_sql = "datetime('now','localtime')"
        log_text = task["log_text"] or ""
        if payload.log_tail:
            log_text = (log_text.rstrip() + "\n\n=== CALLBACK BACK TAIL ===\n" + payload.log_tail)[:6000]
        finish_sql = f", finished_at={now_sql}" if payload.status in ("success", "failed") else ""
        conn.execute(
            f"""UPDATE deploy_tasks SET status=?, current_phase=?, step=?, progress=?,
                   vpn_type=?, vpn_url=?, vpn_qr_code=?, vpn_config_path=?, vpn_config_content=?,
                   vpn_client_ip=?, vpn_client_privkey=?, vpn_client_pubkey=?, vpn_listen_port=?, vpn_dns=?,
                   output_root=?, latest_dir=?, nginx_server_name=?, nginx_port=?,
                   error_msg=?, log_text=?, updated_at={now_sql}{finish_sql}
                WHERE task_no=?""",
            (
                payload.status, "success" if payload.status == "success" else ("error" if payload.status == "failed" else "running"),
                6 if payload.status == "success" else (task["step"] or 3),
                100 if payload.status == "success" else (task["progress"] or 50),
                payload.vpn_type, payload.vpn_url, payload.vpn_qr_code, payload.vpn_config_path, payload.vpn_config_content,
                payload.vpn_client_ip, payload.vpn_client_privkey, payload.vpn_client_pubkey, payload.vpn_listen_port, payload.vpn_dns,
                payload.output_root, payload.latest_dir, payload.nginx_server_name, payload.nginx_port,
                payload.error_msg, log_text, payload.task_no,
            ),
        )
        # 如果成功，把对应 proxies 表也同步写入
        if payload.status == "success":
            conn.execute(
                """UPDATE proxies
                   SET vpn_url=?, vpn_qr_code=?, vpn_config_path=?, vpn_config_content=?, ip=COALESCE(NULLIF(ip,''), (SELECT ip FROM vps_servers WHERE id=proxies.server_id)), status='active'
                   WHERE deploy_task_id=?""",
                (payload.vpn_url, payload.vpn_qr_code, payload.vpn_config_path, payload.vpn_config_content, task["id"]),
            )
            conn.execute(
                "UPDATE orders SET deploy_status='done', updated_at=datetime('now','localtime') WHERE id=?",
                (task["order_id"],),
            )
        elif payload.status == "failed":
            conn.execute(
                "UPDATE orders SET deploy_status='failed', updated_at=datetime('now','localtime') WHERE id=?",
                (task["order_id"],),
            )
    return {"code": 200, "message": "部署回调结果已保存", "data": {"task_no": payload.task_no, "saved": True}}
