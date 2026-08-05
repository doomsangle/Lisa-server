from datetime import datetime, timedelta, timezone
from typing import Optional, List
import re

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .config import get_settings
from .database import get_conn

settings = get_settings()
security = HTTPBearer(auto_error=False)


def hash_password(pw: str) -> str:
    return bcrypt.hashpw(pw.encode("utf-8"), bcrypt.gensalt(rounds=10)).decode("utf-8")


def verify_password(pw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(pw.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def issue_token(user_id: int, username: str, roles: List[str], permissions: List[str]) -> str:
    payload = {
        "uid": user_id,
        "username": username,
        "roles": roles,
        "permissions": permissions,
        "exp": datetime.now(timezone.utc) + timedelta(hours=settings.JWT_EXPIRE_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
    except jwt.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"登录已过期: {e}")


def get_user_roles_perms(user_id: int):
    with get_conn() as conn:
        role_rows = conn.execute(
            """
            SELECT r.code, r.name FROM user_roles ur
            JOIN roles r ON ur.role_code = r.code
            WHERE ur.user_id = ?
            ORDER BY r.id ASC
            """,
            (user_id,),
        ).fetchall()
        roles = [r["code"] for r in role_rows]
        role_names = [r["name"] for r in role_rows]
        permissions: List[str] = []
        if roles:
            q = ",".join(["?"] * len(roles))
            perm_rows = conn.execute(
                f"SELECT DISTINCT permission_code FROM role_permissions WHERE role_code IN ({q})",
                roles,
            ).fetchall()
            permissions = [r["permission_code"] for r in perm_rows]
        return roles, role_names, permissions


def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)):
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail="未登录")
    payload = decode_token(credentials.credentials)
    uid = payload.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="登录已过期")
    with get_conn() as conn:
        user = conn.execute("SELECT * FROM users WHERE id = ?", (uid,)).fetchone()
    if not user or user["status"] != "active":
        raise HTTPException(status_code=401, detail="账号不存在或被禁用")
    roles, role_names, permissions = get_user_roles_perms(uid)
    user_dict = dict(user)
    user_dict["roles"] = roles
    user_dict["role_names"] = role_names
    user_dict["permissions"] = permissions
    user_dict["is_super_admin"] = "super_admin" in roles
    return user_dict


def require_permission(perm: str):
    def checker(user=Depends(get_current_user)):
        if user["is_super_admin"]:
            return user
        if perm in user["permissions"]:
            return user
        raise HTTPException(status_code=403, detail="无权限访问")

    return checker


def require_role(*role_list: str):
    def checker(user=Depends(get_current_user)):
        if user["is_super_admin"]:
            return user
        if any(r in user["roles"] for r in role_list):
            return user
        raise HTTPException(status_code=403, detail="无权限访问")

    return checker


def valid_username(u: str) -> bool:
    return bool(re.match(r"^[a-zA-Z0-9_]{3,20}$", u or ""))


def valid_email(e: str) -> bool:
    return bool(re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", e or ""))


def uid_int(user) -> int:
    """强制归一化 user.id 为 int（数据库里 user_id 都是 INTEGER，避免类型不匹配）"""
    try:
        return int(user["id"])
    except Exception:
        raise HTTPException(status_code=401, detail="登录态不完整")


def scope_uid(user, all_flag=None) -> Optional[int]:
    """统一数据范围工具：
       - 如果是超级管理员 且 显式传了 all_flag == "1" → 返回 None（不过滤，看全部）
       - 其他所有情况 → 返回当前 user_id 的 int 值
       用于所有列表查询接口，避免漏掉 user_id 过滤。
    """
    if all_flag == "1" and user.get("is_super_admin"):
        return None
    return uid_int(user)


def enforce_owner_or_super(user, obj, field="user_id", action="访问"):
    """鉴权双保险：
       - super_admin 直接放行
       - 否则要求 obj[field] 的 int 值严格等于 user.id
       - 不满足则抛 403
       所有 UPDATE/DELETE 单条操作和详情接口都应调用，避免仅靠权限遗漏数据归属校验
    """
    if user.get("is_super_admin"):
        return
    if obj is None:
        raise HTTPException(status_code=404, detail="记录不存在")
    try:
        own = int(obj.get(field)) if obj.get(field) is not None else None
    except Exception:
        own = None
    if own != uid_int(user):
        raise HTTPException(status_code=403, detail=f"无权{action}他人数据")
