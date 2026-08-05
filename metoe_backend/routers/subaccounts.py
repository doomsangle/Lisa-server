"""
子账号管理接口
主子账号关系：user_relationships 表，parent_id → child_id（唯一）
子账号特点：
  - 独立用户名/密码/邮箱/API Key 登录
  - 资金独立但由主账号划转或限额（max_balance）
  - 权限从主账号继承，可精细裁剪（permissions JSON 字段）
  - 操作产生的服务器/订单资源归属于 child_id
"""
import time, json, random
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import (get_current_user, require_permission, uid_int,
                           hash_password, valid_username, valid_email)
from core.audit import write_audit

router = APIRouter(prefix="/subaccounts", tags=["子账号管理"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


SUB_DEFAULT_PERMS = [
    "dashboard:view", "proxies:view", "servers:view", "deploy:view", "deploy:run",
    "orders:create", "orders:view", "payment:pay", "payment:view",
    "check:run", "check:history", "feedback:create", "feedback:reply",
    "kyc:submit", "kyc:view", "developer:view",
    "transactions:view", "notifications:view", "wallet:transfer",
]


# ============ 列表 ============
@router.get("")
def sub_list(
    keyword: Optional[str] = None,
    status: Optional[str] = None,
    page: int = 1, page_size: int = 20,
    user=Depends(require_permission("subaccounts:view")),
):
    uid = uid_int(user)
    is_sa = user.get("is_super_admin")
    # super_admin with all=1 可以看所有人的子账号；其他只能看自己的子账号
    wh, params = [], []
    if not is_sa:
        wh.append("ur.parent_id = ?"); params.append(uid)
    if status:
        wh.append("ur.status = ?"); params.append(status)
    if keyword:
        wh.append("(u.username LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)")
        kw = f"%{keyword}%"
        params.extend([kw, kw, kw])
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(
            f"""SELECT COUNT(*) c FROM user_relationships ur
           JOIN users u ON u.id = ur.child_id
                {where}""",
            params,
        ).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT ur.*, u.username, u.email, u.phone, u.status user_status,
                       u.created_at user_created_at, u.last_login_at, u.balance
                  FROM user_relationships ur
                  JOIN users u ON u.id = ur.child_id
                {where}
              ORDER BY ur.id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        try:
            perms = json.loads(rd.get("permissions") or "[]")
        except Exception:
            perms = []
        list_.append({
            "id": rd["id"],
            "childId": rd["child_id"],
            "parentId": rd["parent_id"],
            "username": rd["username"],
            "email": rd.get("email"),
            "phone": rd.get("phone"),
            "status": rd["status"],
            "userStatus": rd.get("user_status"),
            "balance": f"{float(rd.get('balance') or 0):.2f}",
            "subBalance": f"{float(rd.get('current_balance') or 0):.2f}",
            "maxBalance": f"{float(rd.get('max_balance') or 0):.2f}" if rd.get("max_balance") else None,
            "permissions": perms,
            "relationType": rd.get("relation_type", "subaccount"),
            "lastLoginAt": rd.get("last_login_at"),
            "createdAt": rd["created_at"],
            "userCreatedAt": rd.get("user_created_at"),
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


# ============ 创建子账号 ============
class CreateSubReq(BaseModel):
    username: str = Field(min_length=3, max_length=20)
    password: str = Field(min_length=6, max_length=32)
    email: Optional[str] = None
    phone: Optional[str] = None
    nickname: Optional[str] = None
    max_balance: Optional[float] = None
    permissions: List[str] = []
    remark: Optional[str] = None


@router.post("")
def sub_create(req: CreateSubReq, request: Request, user=Depends(require_permission("subaccounts:manage"))):
    if not valid_username(req.username):
        return fail("用户名格式不正确（3-20位字母/数字/下划线）")
    if req.email and not valid_email(req.email):
        return fail("邮箱格式不正确")
    if req.phone and len(req.phone or "") < 6:
        return fail("手机号格式不正确")
    uid = uid_int(user)
    with get_conn() as conn:
        exists = conn.execute("SELECT id FROM users WHERE username=?", (req.username,)).fetchone()
        if exists:
            return fail("用户名已被占用")
        if req.email:
            e_exists = conn.execute("SELECT id FROM users WHERE email=?", (req.email,)).fetchone()
            if e_exists:
                return fail("邮箱已被使用")
        pwd_hash = hash_password(req.password)
        default_email = req.email or f"sub_{req.username}@metoe.io"
        sub_id = conn.execute(
            "INSERT INTO users (username, email, phone, password_hash, balance, status) VALUES (?,?,?,?,?, 'active')",
            (req.username, default_email, req.phone, pwd_hash, 0.0),
        ).lastrowid
        # 绑定 user 角色（所有子账号默认 user 基础角色）
        conn.execute(
            "INSERT OR IGNORE INTO user_roles (user_id, role_code) VALUES (?, 'user')",
            (sub_id,),
        )
        selected_perms = req.permissions if req.permissions else SUB_DEFAULT_PERMS
        # 过滤：子账号权限只能是主账号权限子集
        parent_perms = set(user.get("permissions") or [])
        safe_perms = [p for p in selected_perms if p in parent_perms or user.get("is_super_admin")]
        rel_id = conn.execute(
            """INSERT INTO user_relationships
               (parent_id, child_id, relation_type, permissions, max_balance, current_balance, status)
               VALUES (?,?, 'subaccount', ?, ?, 0, 'active')""",
            (uid, sub_id, json.dumps(safe_perms, ensure_ascii=False),
             (round(float(req.max_balance), 2) if req.max_balance and req.max_balance > 0 else None)),
        ).lastrowid

    write_audit(user, action="role_grant", level="high", resource_type="subaccount",
                resource_id=str(sub_id), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"创建子账号 {req.username}",
                new={"child": req.username, "email": default_email, "perms_count": len(safe_perms)})
    return ok({
        "relationId": rel_id,
        "childId": sub_id,
        "username": req.username,
        "email": default_email,
        "permissions": safe_perms,
        "maxBalance": req.max_balance,
    }, "子账号创建成功")


# ============ 更新权限/额度 ============
class UpdateSubReq(BaseModel):
    permissions: Optional[List[str]] = None
    max_balance: Optional[float] = None
    status: Optional[str] = None


@router.put("/{child_id}")
def sub_update(
    child_id: int, req: UpdateSubReq, request: Request,
    user=Depends(require_permission("subaccounts:manage")),
):
    uid = uid_int(user)
    with get_conn() as conn:
        rel = conn.execute(
            "SELECT * FROM user_relationships WHERE parent_id=? AND child_id=?",
            (uid, child_id),
        ).fetchone()
        if not rel and not user.get("is_super_admin"):
            raise HTTPException(status_code=403, detail="只能管理自己的子账号")
        if not rel:
            rel = conn.execute("SELECT * FROM user_relationships WHERE child_id=?", (child_id,)).fetchone()
            if not rel:
                return fail("子账号不存在")
        sets, params = [], []
        if req.permissions is not None:
            parent_perms = set(user.get("permissions") or [])
            safe_perms = [p for p in req.permissions if p in parent_perms or user.get("is_super_admin")]
            sets.append("permissions = ?"); params.append(json.dumps(safe_perms, ensure_ascii=False))
        if req.max_balance is not None:
            sets.append("max_balance = ?")
            params.append(round(float(req.max_balance), 2) if req.max_balance > 0 else None)
        if req.status and req.status in ["active", "disabled"]:
            sets.append("status = ?"); params.append(req.status)
            conn.execute("UPDATE users SET status=?, updated_at=datetime('now','localtime') WHERE id=?",
                         ("active" if req.status == "active" else "disabled", child_id))
        if sets:
            sets.append("updated_at = datetime('now','localtime')")
            conn.execute(
                f"UPDATE user_relationships SET {', '.join(sets)} WHERE id=?",
                params + [rel["id"]],
            )
    write_audit(user, action="role_grant", level="high", resource_type="subaccount",
                resource_id=str(child_id), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"更新子账号 #{child_id} 配置",
                new=dict(req))
    return ok(None, "子账号配置已更新")


# ============ 重置子账号密码 ============
class ResetPwdReq(BaseModel):
    new_password: Optional[str] = Field(None, min_length=6, max_length=32)
    password: Optional[str] = Field(None, min_length=6, max_length=32)


@router.post("/{child_id}/reset-password")
def sub_reset_pwd(
    child_id: str, req: ResetPwdReq, request: Request,
    user=Depends(require_permission("subaccounts:manage")),
):
    uid = uid_int(user)
    pwd_raw = req.new_password or req.password
    if not pwd_raw:
        return fail("请提供新密码（8-32位）")
    with get_conn() as conn:
        child_id_int = None
        try:
            child_id_int = int(child_id)
        except (ValueError, TypeError):
            u = conn.execute("SELECT id FROM users WHERE username=?", (child_id,)).fetchone()
            if not u:
                return fail(f"子账号 [{child_id}] 不存在")
            child_id_int = int(u["id"])
        rel = conn.execute(
            "SELECT * FROM user_relationships WHERE parent_id=? AND child_id=?",
            (uid, child_id_int),
        ).fetchone()
        if not rel and not user.get("is_super_admin"):
            raise HTTPException(status_code=403, detail="只能管理自己的子账号")
        child_user = conn.execute("SELECT username FROM users WHERE id=?", (child_id_int,)).fetchone()
        child_uname = child_user["username"] if child_user else str(child_id_int)
        pwd_hash = hash_password(pwd_raw)
        conn.execute(
            "UPDATE users SET password_hash=?, updated_at=datetime('now','localtime') WHERE id=?",
            (pwd_hash, child_id_int),
        )
    write_audit(user, action="change_password", level="high", resource_type="subaccount",
                resource_id=str(child_id_int), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"重置子账号 {child_uname}(#{child_id_int}) 的登录密码为 {len(pwd_raw)} 位")
    return ok(None, f"{child_uname} 密码重置成功")


# ============ 删除子账号 ============
@router.delete("/{child_id}")
def sub_delete(
    child_id: int, request: Request,
    user=Depends(require_permission("subaccounts:manage")),
):
    uid = uid_int(user)
    with get_conn() as conn:
        rel = conn.execute(
            "SELECT * FROM user_relationships WHERE parent_id=? AND child_id=?",
            (uid, child_id),
        ).fetchone()
        if not rel and not user.get("is_super_admin"):
            raise HTTPException(status_code=403, detail="只能管理自己的子账号")
        if not rel:
            return fail("子账号不存在")
        # 子账号还有余额，需要先划转
        bal_row = conn.execute("SELECT balance FROM users WHERE id=?", (child_id,)).fetchone()
        if float(bal_row["balance"] or 0) > 0:
            return fail("子账号还有余额，请先划转清空后再删除")
        conn.execute("DELETE FROM user_relationships WHERE child_id=?", (child_id,))
        # 子账号资源全部置为禁用（不硬删除）
        conn.execute("UPDATE users SET status='disabled', updated_at=datetime('now','localtime') WHERE id=?", (child_id,))
    write_audit(user, action="user_ban", level="high", resource_type="subaccount",
                resource_id=str(child_id), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"删除/禁用子账号 #{child_id}")
    return ok(None, "子账号已删除")


# ============ 可用权限树 ============
@router.get("/permissions/available")
def sub_perms_available(user=Depends(require_permission("subaccounts:view"))):
    parent_perms = set(user.get("permissions") or [])
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT code, name, group_name FROM permissions ORDER BY group_name, id ASC"
        ).fetchall()
    groups = {}
    for r in rows:
        rd = dict(r)
        code = rd["code"]
        # 子账号可选用的权限必须是主账号自己拥有的（超管不受限）
        if not user.get("is_super_admin") and code not in parent_perms:
            continue
        g = rd["group_name"] or "其他"
        groups.setdefault(g, []).append({"code": code, "name": rd["name"]})
    tree = [{"group": g, "items": items} for g, items in groups.items()]
    return ok({"groups": tree, "defaults": SUB_DEFAULT_PERMS})
