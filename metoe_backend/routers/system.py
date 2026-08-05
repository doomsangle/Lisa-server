from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import (
    get_current_user, require_permission, require_role,
    hash_password, valid_email, valid_username, get_user_roles_perms,
)

router = APIRouter(prefix="/system", tags=["系统管理"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


def _list_roles():
    with get_conn() as conn:
        roles = [dict(r) for r in conn.execute(
            "SELECT * FROM roles ORDER BY id ASC"
        ).fetchall()]
        for r in roles:
            r["protected"] = bool(r["protected"])
            r["userCount"] = conn.execute(
                "SELECT COUNT(*) c FROM user_roles WHERE role_code=?", (r["code"],)
            ).fetchone()["c"]
            perms = conn.execute(
                "SELECT permission_code FROM role_permissions WHERE role_code=?", (r["code"],)
            ).fetchall()
            r["permissions"] = [p["permission_code"] for p in perms]
    return roles


@router.get("/users")
def users_list(
    page: int = 1, pageSize: int = 20,
    keyword: Optional[str] = None, role: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_permission("system:users:view")),
):
    wh, params = [], []
    if keyword:
        wh.append("(u.username LIKE ? OR u.email LIKE ?)")
        params.extend([f"%{keyword}%", f"%{keyword}%"])
    if status:
        wh.append("u.status = ?"); params.append(status)
    if role:
        role_join = "JOIN user_roles ur ON ur.user_id = u.id AND ur.role_code = ?"
        params.insert(0, role)
    else:
        role_join = ""
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(DISTINCT u.id) c FROM users u {role_join} {where}", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"SELECT u.* FROM users u {role_join} {where} ORDER BY u.id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    list_ = []
    for r in rows:
        roles, role_names, _ = get_user_roles_perms(r["id"])
        list_.append({
            "id": r["id"], "username": r["username"], "email": r["email"],
            "balance": f"{float(r['balance']):.2f}", "status": r["status"],
            "roles": roles, "roleNames": role_names,
            "lastLoginAt": r["last_login_at"], "createdAt": r["created_at"],
            "statusSwitch": r["status"] == "active",
        })
    return ok({"total": total, "page": page, "pageSize": pageSize, "list": list_})


class CreateUserReq(BaseModel):
    username: str
    email: str
    password: str = Field(min_length=6)
    roles: List[str] = ["user"]
    balance: float = 0
    status: str = "active"


class UpdateUserReq(BaseModel):
    email: Optional[str] = None
    roles: Optional[List[str]] = None
    balance: Optional[float] = None
    status: Optional[str] = None


@router.post("/users")
def create_user(req: CreateUserReq, user=Depends(require_permission("system:users:manage"))):
    if not valid_username(req.username):
        return fail("用户名格式错误")
    if not valid_email(req.email):
        return fail("邮箱格式错误")
    with get_conn() as conn:
        if conn.execute(
            "SELECT id FROM users WHERE username=? OR email=?", (req.username, req.email)
        ).fetchone():
            return fail("用户名或邮箱已存在")
        uid = conn.execute(
            "INSERT INTO users (username, email, password_hash, balance, status) VALUES (?,?,?,?,?)",
            (req.username, req.email, hash_password(req.password), float(req.balance), req.status),
        ).lastrowid
        stmt = conn.execute
        for rc in req.roles:
            conn.execute(
                "INSERT OR IGNORE INTO user_roles (user_id, role_code) VALUES (?,?)", (uid, rc)
            )
    return ok({"id": uid}, "创建成功")


@router.put("/users/{id_}")
def update_user(id_: int, req: UpdateUserReq, user=Depends(require_permission("system:users:manage"))):
    with get_conn() as conn:
        u = conn.execute("SELECT * FROM users WHERE id=?", (id_,)).fetchone()
        if not u:
            return fail("用户不存在", 404)
        conn.execute(
            """UPDATE users SET
                 email=COALESCE(?,email),
                 balance=COALESCE(?,balance),
                 status=COALESCE(?,status),
                 updated_at=datetime('now','localtime')
               WHERE id=?""",
            (req.email, req.balance, req.status, id_),
        )
        if req.roles is not None:
            conn.execute("DELETE FROM user_roles WHERE user_id=?", (id_,))
            for rc in req.roles:
                conn.execute(
                    "INSERT OR IGNORE INTO user_roles (user_id, role_code) VALUES (?,?)", (id_, rc)
                )
    return ok(None, "更新成功")


class RechargeReq(BaseModel):
    amount: float
    remark: Optional[str] = ""


@router.post("/users/{id_}/recharge")
def recharge(
    id_: int, req: RechargeReq,
    user=Depends(require_role("super_admin", "admin", "finance")),
):
    a = float(req.amount)
    if not a:
        return fail("金额错误")
    with get_conn() as conn:
        u = conn.execute("SELECT * FROM users WHERE id=?", (id_,)).fetchone()
        if not u:
            return fail("用户不存在", 404)
        before = float(u["balance"])
        after = before + a
        conn.execute(
            "UPDATE users SET balance=?, updated_at=datetime('now','localtime') WHERE id=?",
            (after, id_),
        )
        conn.execute(
            "INSERT INTO transactions (user_id, type, amount, balance_before, balance_after, remark) "
            "VALUES (?,?,?,?,?,?)",
            (id_, "recharge" if a > 0 else "deduct", a, before, after,
             req.remark or ("手动充值" if a > 0 else "手动扣款")),
        )
    return ok({"newBalance": f"{after:.2f}"}, "充值成功" if a > 0 else "扣款成功")


class ResetPwdReq(BaseModel):
    password: str = Field(min_length=6, default="123456")


@router.post("/users/{id_}/reset-password")
def reset_pwd(
    id_: int, req: ResetPwdReq,
    user=Depends(require_permission("system:users:manage")),
):
    with get_conn() as conn:
        conn.execute(
            "UPDATE users SET password_hash=?, updated_at=datetime('now','localtime') WHERE id=?",
            (hash_password(req.password), id_),
        )
    return ok({"tempPassword": req.password}, "密码已重置")


@router.delete("/users/{id_}")
def delete_user(id_: int, user=Depends(require_role("super_admin"))):
    if int(id_) == int(user["id"]):
        return fail("不能删除自己")
    with get_conn() as conn:
        conn.execute("DELETE FROM users WHERE id=?", (id_,))
    return ok(None, "已删除")


@router.get("/roles")
def roles_list(user=Depends(require_permission("system:roles:view"))):
    return ok(_list_roles())


@router.get("/permissions")
def perms_tree(user=Depends(require_permission("system:roles:view"))):
    with get_conn() as conn:
        rows = [dict(r) for r in conn.execute(
            "SELECT * FROM permissions ORDER BY group_name, id"
        ).fetchall()]
    groups_map = {}
    for p in rows:
        g = p["group_name"] or "其他"
        groups_map.setdefault(g, {"code": g, "name": g, "children": []})
        groups_map[g]["children"].append({"code": p["code"], "name": p["name"]})
    return ok({"groups": list(groups_map.values()), "list": rows})


class CreateRoleReq(BaseModel):
    code: str
    name: str
    description: Optional[str] = ""


class UpdateRoleReq(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


@router.post("/roles")
def create_role(req: CreateRoleReq, user=Depends(require_permission("system:roles:manage"))):
    import re
    if not re.match(r"^[a-z][a-z0-9_]{1,31}$", req.code):
        return fail("角色标识 2-32 位小写字母数字下划线")
    if not req.name:
        return fail("请输入名称")
    try:
        with get_conn() as conn:
            conn.execute(
                "INSERT INTO roles (code, name, description, protected) VALUES (?,?,?,0)",
                (req.code, req.name, req.description or ""),
            )
    except Exception:
        return fail("标识已存在")
    return ok(None, "创建成功")


@router.put("/roles/{code}")
def update_role(code: str, req: UpdateRoleReq, user=Depends(require_permission("system:roles:manage"))):
    with get_conn() as conn:
        conn.execute(
            "UPDATE roles SET name=COALESCE(?,name), description=COALESCE(?,description) WHERE code=?",
            (req.name, req.description, code),
        )
    return ok(None, "已更新")


@router.delete("/roles/{code}")
def del_role(code: str, user=Depends(require_role("super_admin"))):
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM roles WHERE code=?", (code,)).fetchone()
        if not r:
            return fail("角色不存在", 404)
        if r["protected"]:
            return fail("系统内置角色不可删除")
        conn.execute("DELETE FROM roles WHERE code=?", (code,))
    return ok(None, "已删除")


class SavePermsReq(BaseModel):
    permissions: List[str] = []


@router.post("/roles/{code}/permissions")
def save_perms(code: str, req: SavePermsReq, user=Depends(require_permission("system:roles:manage"))):
    with get_conn() as conn:
        conn.execute("DELETE FROM role_permissions WHERE role_code=?", (code,))
        for p in req.permissions:
            conn.execute(
                "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
                (code, p),
            )
    return ok({"count": len(req.permissions)}, "已保存")
