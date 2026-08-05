from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import get_current_user, require_permission, enforce_owner_or_super, uid_int
from core.audit import write_audit

router = APIRouter(prefix="/feedbacks", tags=["反馈工单"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


FB_STATUS_FLOW = ["open", "processing", "replied", "closed"]
FB_TYPES = {"bug": "Bug反馈", "feature": "功能建议", "consult": "咨询求助", "bill": "账单问题"}


class CreateReq(BaseModel):
    type: str
    priority: str = "normal"
    title: str = Field(min_length=5)
    content: str = Field(min_length=10)
    refId: Optional[str] = None
    attachments: Optional[str] = None


@router.post("")
def create(req: CreateReq, request: Request, user=Depends(require_permission("feedback:create"))):
    if req.type not in FB_TYPES:
        return fail("类型错误")
    with get_conn() as conn:
        id_ = conn.execute(
            """INSERT INTO feedbacks (user_id, type, priority, title, content, ref_id, unread)
               VALUES (?,?,?,?,?,?, 0)""",
            (user["id"], req.type, req.priority, req.title, req.content, req.refId),
        ).lastrowid
        # 首条内容作为用户自己的第一条回复（便于统一回复流展示）
        conn.execute(
            """INSERT INTO feedback_replies
               (feedback_id, user_id, username, role, content, attachments, is_internal)
               VALUES (?,?,?, 'user',?,?, 0)""",
            (id_, user["id"], user["username"], req.content, (req.attachments or "")[:500]),
        )
        # 通知管理员有新工单
        admin_rows = conn.execute("""
            SELECT u.id FROM users u
            JOIN user_roles ur ON ur.user_id = u.id
            WHERE ur.role_code IN ('super_admin','admin','support')
        """).fetchall()
        for ar in admin_rows:
            conn.execute(
                """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                   VALUES (?, 'feedback', ?, ?, 'warning', 'feedback', ?)""",
                (ar["id"], f"新工单 #{id_}",
                 f"{user['username']} 提交了【{FB_TYPES.get(req.type, req.type)}】工单：{req.title[:30]}",
                 str(id_)),
            )
    write_audit(user, action="order_create", level="low", resource_type="feedback",
                resource_id=str(id_), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"提交工单 #{id_}：{req.title}")
    return ok({"id": id_, "ticketNo": f"TK{100000 + id_}"}, "工单提交成功")


@router.get("")
def list_fb(
    status: Optional[str] = None,
    type_: Optional[str] = None,
    keyword: Optional[str] = None,
    page: int = 1, page_size: int = 50,
    all: Optional[str] = None,
    user=Depends(get_current_user),
):
    can_manage = user.get("is_super_admin") or ("feedback:manage" in user["permissions"])
    where_parts = []
    params = []
    uid = uid_int(user)
    if not (all == "1" and can_manage):
        where_parts.append("(f.user_id = ?")
        params.append(uid)
        if can_manage:
            # 管理员可以看被分配或自己回复过的（简化：管理员/客服默认看全部）
            pass
        where_parts[-1] = where_parts[-1].rstrip("(") if False else where_parts[-1] + ")"
    if not can_manage:
        where_parts[-1] = f"f.user_id = ?"
        params = [uid]
    if status:
        where_parts.append("f.status = ?"); params.append(status)
    if type_:
        where_parts.append("f.type = ?"); params.append(type_)
    if keyword:
        where_parts.append("(f.title LIKE ? OR f.content LIKE ?)")
        kw = f"%{keyword}%"; params.extend([kw, kw])
    where = ("WHERE " + " AND ".join(where_parts)) if where_parts else ""
    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) c FROM feedbacks f {where}", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT f.*, u.username, u.email,
                       (SELECT COUNT(*) FROM feedback_replies r WHERE r.feedback_id = f.id) reply_count,
                       (SELECT MAX(created_at) FROM feedback_replies r WHERE r.feedback_id = f.id) last_reply_at,
                       (SELECT role FROM feedback_replies r WHERE r.feedback_id = f.id
                         ORDER BY r.id DESC LIMIT 1) last_reply_role
                  FROM feedbacks f
             LEFT JOIN users u ON u.id = f.user_id
                {where}
              ORDER BY f.unread DESC, f.id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        list_.append({
            "id": r["id"], "ticketNo": f"TK{100000 + r['id']}",
            "userId": r["user_id"], "username": r.get("username"),
            "type": r["type"], "typeLabel": FB_TYPES.get(r["type"], r["type"]),
            "priority": r["priority"], "title": r["title"],
            "status": r["status"], "unread": r["unread"],
            "refId": r["ref_id"], "content": r["content"],
            "replyCount": r["reply_count"] or 0,
            "lastReplyAt": r.get("last_reply_at"),
            "lastReplyRole": r.get("last_reply_role"),
            "createdAt": r["created_at"],
            "ts": (r["created_at"] or "").replace("T", " ")[:16],
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


@router.get("/{id_}")
def detail(id_: int, user=Depends(get_current_user)):
    can_manage = user.get("is_super_admin") or ("feedback:manage" in user["permissions"])
    uid = uid_int(user)
    with get_conn() as conn:
        r = conn.execute(
            """SELECT f.*, u.username, u.email, u.phone
                 FROM feedbacks f LEFT JOIN users u ON u.id = f.user_id
                WHERE f.id = ?""", (id_,),
        ).fetchone()
        if not r:
            return fail("不存在", 404)
        if not can_manage and r["user_id"] != uid:
            raise HTTPException(status_code=403, detail="无权限")
        # 用户打开工单，自己的未读数清零
        if r["user_id"] == uid:
            conn.execute("UPDATE feedbacks SET unread = 0 WHERE id=?", (id_,))
        # 加载回复列表
        replies = conn.execute(
            """SELECT r.*, u.username, u.email
                 FROM feedback_replies r
            LEFT JOIN users u ON u.id = r.user_id
                WHERE r.feedback_id = ?
                  AND (r.is_internal = 0 OR ?)
             ORDER BY r.id ASC""",
            (id_, 1 if can_manage else 0),
        ).fetchall()
    reply_list = []
    for rp in replies:
        rd = dict(rp)
        reply_list.append({
            "id": rd["id"], "feedbackId": rd["feedback_id"],
            "userId": rd["user_id"], "username": rd.get("username") or rd.get("username"),
            "role": rd["role"],  # user / admin / support
            "roleLabel": {"user": "用户", "admin": "管理员", "support": "客服"}.get(rd["role"], rd["role"]),
            "content": rd["content"], "attachments": rd.get("attachments"),
            "isInternal": bool(rd["is_internal"]),
            "createdAt": rd["created_at"],
            "ts": (rd["created_at"] or "").replace("T", " ")[:16],
        })
    return ok({
        "id": r["id"], "ticketNo": f"TK{100000 + r['id']}",
        "userId": r["user_id"], "username": r.get("username"),
        "userEmail": r.get("email"), "userPhone": r.get("phone"),
        "type": r["type"], "typeLabel": FB_TYPES.get(r["type"], r["type"]),
        "priority": r["priority"], "title": r["title"],
        "content": r["content"], "status": r["status"],
        "refId": r["ref_id"], "unread": r["unread"],
        "createdAt": r["created_at"],
        "replyCount": len(reply_list),
        "replies": reply_list,
        "canReply": True,
    })


# ========== 新增：回复工单（双向流） ==========
class ReplyReq(BaseModel):
    content: str = Field(min_length=2, max_length=3000)
    attachments: Optional[str] = None
    isInternal: bool = False


@router.post("/{id_}/replies")
def create_reply(
    id_: int, req: ReplyReq, request: Request,
    user=Depends(require_permission("feedback:reply")),
):
    can_manage = user.get("is_super_admin") or ("feedback:manage" in user["permissions"])
    uid = uid_int(user)
    if req.isInternal and not can_manage:
        return fail("仅客服/管理员可发送内部备注")
    with get_conn() as conn:
        fb = conn.execute("SELECT * FROM feedbacks WHERE id=?", (id_,)).fetchone()
        if not fb:
            return fail("工单不存在", 404)
        if not can_manage and fb["user_id"] != uid:
            raise HTTPException(status_code=403, detail="无权回复他人工单")
        role_determine = "user"
        if can_manage:
            role_determine = "support" if "support" in user["roles"] else "admin"
        rid = conn.execute(
            """INSERT INTO feedback_replies
               (feedback_id, user_id, username, role, content, attachments, is_internal)
               VALUES (?,?,?,?,?,?,?)""",
            (id_, uid, user["username"], role_determine, req.content,
             (req.attachments or "")[:500], 1 if req.isInternal else 0),
        ).lastrowid
        # 更新工单状态 + 未读数（给对方看的）
        if role_determine == "user":
            # 用户回复 → 工单回到 processing，未读数+1（给管理员看）
            conn.execute(
                "UPDATE feedbacks SET status=CASE WHEN status='closed' THEN 'open' ELSE COALESCE(NULLIF(status,'replied'),status) END, unread=unread+1, updated_at=datetime('now','localtime') WHERE id=?",
                (id_,),
            )
            # 通知管理员有用户回复
            admin_rows = conn.execute("""
                SELECT u.id FROM users u
                JOIN user_roles ur ON ur.user_id = u.id
                WHERE ur.role_code IN ('super_admin','admin','support')
            """).fetchall()
            for ar in admin_rows:
                conn.execute(
                    """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                       VALUES (?, 'feedback', ?, ?, 'info', 'feedback', ?)""",
                    (ar["id"], f"工单 #{id_} 有新回复",
                     f"{user['username']} 回复了工单【{fb['title'][:20]}】：{req.content[:30]}",
                     str(id_)),
                )
            target_status = "processing" if fb["status"] not in ("closed",) else fb["status"]
            if target_status != fb["status"]:
                conn.execute("UPDATE feedbacks SET status=? WHERE id=?", (target_status, id_))
        else:
            # 管理员回复 → 状态 replied，用户端 unread+1
            conn.execute(
                "UPDATE feedbacks SET status='replied', unread=unread+1, updated_at=datetime('now','localtime') WHERE id=?",
                (id_,),
            )
            # 通知用户有回复
            notify_uid = fb["user_id"]
            conn.execute(
                """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                   VALUES (?, 'feedback', ?, ?, 'success', 'feedback', ?)""",
                (notify_uid, f"工单 #{id_} 客服已回复",
                 f"您的工单【{fb['title'][:20]}】收到客服回复：{req.content[:30]}",
                 str(id_)),
            )
    write_audit(user, action="server_op", level="low", resource_type="feedback",
                resource_id=str(id_), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"回复工单 #{id_}（{role_determine}）")
    return ok({"replyId": rid, "role": role_determine}, "回复成功")


class StatusReq(BaseModel):
    status: str


@router.put("/{id_}/status")
def status(id_: int, req: StatusReq, request: Request, user=Depends(require_permission("feedback:manage"))):
    if req.status not in FB_STATUS_FLOW:
        return fail("状态错误，可选：" + ", ".join(FB_STATUS_FLOW))
    uid = uid_int(user)
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM feedbacks WHERE id=?", (id_,)).fetchone()
        if not row:
            return fail("不存在", 404)
        if not user.get("is_super_admin") and "feedback:manage" not in user["permissions"]:
            if row["user_id"] != uid:
                raise HTTPException(status_code=403, detail="无权限")
        inc = 1 if req.status == "replied" else 0
        conn.execute(
            "UPDATE feedbacks SET status=?, unread=unread+?, updated_at=datetime('now','localtime') WHERE id=?",
            (req.status, inc, id_),
        )
        # 通知用户状态变更
        if row["user_id"] != uid:
            status_label = {"open": "已开启", "processing": "处理中", "replied": "已回复", "closed": "已关闭"}[req.status]
            conn.execute(
                """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                   VALUES (?, 'feedback', ?, ?, 'info', 'feedback', ?)""",
                (row["user_id"], f"工单 #{id_} 状态更新",
                 f"您的工单【{row['title'][:20]}】状态变为：{status_label}",
                 str(id_)),
            )
    write_audit(user, action="server_op", level="low", resource_type="feedback",
                resource_id=str(id_), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"工单 #{id_} 状态变更 -> {req.status}")
    return ok(None, "已更新")
