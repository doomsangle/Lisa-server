"""
通知中心接口
用户隔离：每个用户只能看自己的通知
支持：列表分页、未读数量、单条标记已读、全部标记已读、删除通知
通知等级：info/success/warning/error
通知类型：system/wallet/order/server/feedback/coupon/security
"""
import time, json
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import get_current_user, require_permission, uid_int

router = APIRouter(prefix="/notifications", tags=["通知中心"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


LEVEL_LABELS = {"info": "普通", "success": "成功", "warning": "警告", "error": "错误"}
TYPE_LABELS = {
    "system": "系统", "wallet": "钱包", "order": "订单",
    "server": "云服务器", "feedback": "工单", "coupon": "优惠券",
    "security": "安全", "deploy": "部署",
}


def push_notification(conn, user_ids: List[int], type_: str, title: str, content: str,
                      level: str = "info", resource_type: str = None, resource_id: str = None):
    """广播工具：给多个用户发通知（无鉴权，需内部调用）。失败不抛异常。"""
    try:
        rows = [(u, type_, title, content, level, resource_type, resource_id) for u in user_ids]
        conn.executemany(
            """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
               VALUES (?,?,?,?,?,?,?)""",
            rows,
        )
    except Exception:
        pass


# ============ 通知列表 ============
@router.get("")
def notifications_list(
    type: Optional[str] = None,
    level: Optional[str] = None,
    is_read: Optional[str] = None,
    page: int = 1, page_size: int = 50,
    user=Depends(require_permission("notifications:view")),
):
    uid = uid_int(user)
    wh, params = ["user_id = ?"], [uid]
    if type:
        wh.append("type = ?"); params.append(type)
    if level:
        wh.append("level = ?"); params.append(level)
    if is_read in ["0", "1"]:
        wh.append("is_read = ?"); params.append(int(is_read))
    where = "WHERE " + " AND ".join(wh)
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM notifications {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT * FROM notifications {where}
              ORDER BY is_read ASC, id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "id": rd["id"], "type": rd["type"],
            "typeLabel": TYPE_LABELS.get(rd["type"], rd["type"]),
            "title": rd["title"], "content": rd["content"],
            "level": rd["level"],
            "levelLabel": LEVEL_LABELS.get(rd["level"], rd["level"]),
            "resourceType": rd.get("resource_type"),
            "resourceId": rd.get("resource_id"),
            "isRead": bool(rd["is_read"]),
            "readAt": rd.get("read_at"),
            "createdAt": rd["created_at"],
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


# ============ 未读数量 + 分类型统计 ============
@router.get("/unread-count")
def notifications_unread_count(user=Depends(get_current_user)):
    uid = uid_int(user)
    with get_conn() as conn:
        total = conn.execute(
            "SELECT COUNT(*) c FROM notifications WHERE user_id=? AND is_read=0",
            (uid,),
        ).fetchone()["c"]
        type_rows = conn.execute(
            """SELECT type, COUNT(*) c FROM notifications
                WHERE user_id=? AND is_read=0
             GROUP BY type ORDER BY c DESC""",
            (uid,),
        ).fetchall()
    by_type = {r["type"]: r["c"] for r in type_rows}
    return ok({
        "total": total,
        "byType": by_type,
        "latest": [],
    })


# ============ 单条标记已读 ============
@router.post("/{nid}/read")
def notifications_mark_read(nid: int, user=Depends(require_permission("notifications:view"))):
    uid = uid_int(user)
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM notifications WHERE id=? AND user_id=?",
            (nid, uid),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="通知不存在")
        conn.execute(
            """UPDATE notifications
                  SET is_read = 1, read_at = datetime('now','localtime')
                WHERE id = ? AND is_read = 0""",
            (nid,),
        )
    return ok(None, "已标记已读")


# ============ 全部标记已读 ============
@router.post("/read-all")
def notifications_mark_all_read(
    type: Optional[str] = None,
    user=Depends(require_permission("notifications:view")),
):
    uid = uid_int(user)
    wh, params = ["user_id=?", "is_read=0"], [uid]
    if type:
        wh.append("type = ?"); params.append(type)
    where = " AND ".join(wh)
    with get_conn() as conn:
        changed = conn.execute(
            f"""UPDATE notifications
                  SET is_read = 1, read_at = datetime('now','localtime')
                WHERE {where}""",
            params,
        ).rowcount
    return ok({"changed": changed}, f"已将 {changed} 条通知标记为已读")


# ============ 删除通知（单条） ============
@router.delete("/{nid}")
def notifications_delete(nid: int, user=Depends(require_permission("notifications:view"))):
    uid = uid_int(user)
    with get_conn() as conn:
        conn.execute(
            "DELETE FROM notifications WHERE id=? AND user_id=?",
            (nid, uid),
        )
    return ok(None, "删除成功")


# ============ 清空已读通知 ============
@router.delete("/clear-read")
def notifications_clear_read(user=Depends(require_permission("notifications:view"))):
    uid = uid_int(user)
    with get_conn() as conn:
        changed = conn.execute(
            "DELETE FROM notifications WHERE user_id=? AND is_read=1",
            (uid,),
        ).rowcount
    return ok({"changed": changed}, f"已清空 {changed} 条已读通知")
