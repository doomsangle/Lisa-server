"""
MetoE 合规审计日志查询路由（对应 ToS 第 2.3 条 / 隐私政策第 1.1 条）
- GET /audit/list  分页+多维度查询
  · 普通用户：只能看自己的日志（scope_uid 默认过滤）
  · super_admin + all=1：查看全平台日志（合规追溯用）
- 不提供 DELETE（审计日志 180 天内只读，由后台清理任务自动过期删除）
"""
from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel

from core.database import get_conn
from core.security import require_permission, get_current_user

router = APIRouter(tags=["审计日志"])


class AuditListReq(BaseModel):
    pass


@router.get("/audit/list")
def audit_list(
    request: Request,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    level: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    kw: Optional[str] = Query(None),
    start: Optional[str] = Query(None),
    end: Optional[str] = Query(None),
    all_data: Optional[str] = Query(None, alias="all"),
    user=Depends(get_current_user),
):
    """查询审计日志列表（数据隔离：普通用户只看自己，超管 + all=1 看全部）"""
    roles = set(user.get("roles") or [])
    is_super = "super_admin" in roles

    where = []
    params = []
    if not is_super or all_data != "1":
        where.append("user_id = ?")
        params.append(user["id"])
    if level and level in ("low", "mid", "high"):
        where.append("level = ?")
        params.append(level)
    if action:
        where.append("action = ?")
        params.append(action)
    if kw:
        # 搜：操作人(username)、IP、资源ID、摘要
        like = f"%{kw}%"
        where.append("(username LIKE ? OR ip LIKE ? OR resource_id LIKE ? OR summary LIKE ?)")
        params.extend([like, like, like, like])
    if start:
        where.append("created_at >= ?")
        params.append(start)
    if end:
        where.append("created_at <= ?")
        params.append(end)

    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    limit = page_size
    offset = (page - 1) * page_size

    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) c FROM audit_logs {where_sql}", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT id, user_id, username, action, level, resource_type, resource_id,
                       old_json, new_json, ip, user_agent, success, summary, created_at
                  FROM audit_logs
                {where_sql}
              ORDER BY id DESC
                 LIMIT ? OFFSET ?""",
            params + [limit, offset],
        ).fetchall()

    items = []
    for r in rows:
        d = dict(r)
        d["ok"] = bool(d.get("success"))
        items.append(d)

    # 超管数据统计卡片（用于首页 dashboard 概览）
    summary_counts = None
    if page == 1 and is_super and all_data == "1":
        with get_conn() as conn2:
            today_count = conn2.execute(
                "SELECT COUNT(*) c FROM audit_logs WHERE date(created_at)=date('now','localtime')"
            ).fetchone()["c"]
            high_count = conn2.execute(
                "SELECT COUNT(*) c FROM audit_logs WHERE level='high' AND created_at >= datetime('now','-7 days','localtime')"
            ).fetchone()["c"]
            fail_count = conn2.execute(
                "SELECT COUNT(*) c FROM audit_logs WHERE success=0 AND created_at >= datetime('now','-7 days','localtime')"
            ).fetchone()["c"]
            summary_counts = {"today": today_count, "high7d": high_count, "fail7d": fail_count}

    return {
        "code": 0,
        "message": "ok",
        "data": {
            "list": items,
            "total": total,
            "page": page,
            "page_size": page_size,
            "summary": summary_counts,
        },
    }


@router.get("/audit/actions")
def audit_action_enums(user=Depends(get_current_user)):
    """返回前后端对齐的审计动作枚举（前端 AuditLog.vue opTypes 用）"""
    from core.audit import AUDIT_ACTIONS
    return {"code": 0, "message": "ok", "data": [
        {"k": k, **v} for k, v in AUDIT_ACTIONS.items()
    ]}
