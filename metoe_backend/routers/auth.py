from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field
import secrets
import json
import re

from core.database import get_conn
from core.security import (
    hash_password, verify_password, issue_token,
    get_current_user, valid_username, valid_email,
    get_user_roles_perms, require_permission, uid_int,
)
from core.config import get_settings
from core.audit import (
    audit_login, audit_logout, audit_update_profile,
    audit_change_pwd, audit_reset_api_key, write_audit,
)

router = APIRouter(prefix="/auth", tags=["认证"])
settings = get_settings()


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


class RegisterReq(BaseModel):
    username: str
    email: str
    password: str = Field(min_length=6, max_length=64)
    phone: Optional[str] = None
    wechat: Optional[str] = None
    qq: Optional[str] = None


class LoginReq(BaseModel):
    username: str
    password: str


class ChangePwdReq(BaseModel):
    old: str
    password: str = Field(min_length=6, max_length=64)


class ProfileUpdateReq(BaseModel):
    phone: Optional[str] = None
    wechat: Optional[str] = None
    qq: Optional[str] = None
    email: Optional[str] = None


class SettingsUpdateReq(BaseModel):
    """个人偏好 & 显示 & 通知 & 操作偏好统一入口（仅保存字段不为 None 的项）"""
    lang: Optional[str] = None                # zh-CN / en-US / zh-HK
    theme: Optional[str] = None               # light / dark / auto
    timezone: Optional[str] = None            # 时区：Asia/Shanghai
    density: Optional[str] = None             # default / compact / loose
    page_size: Optional[int] = Field(None, ge=10, le=200)
    sidebar_collapsed: Optional[int] = None   # 0/1
    currency: Optional[str] = None            # CNY / USD / HKD
    notify_sms: Optional[int] = None          # 短信提醒 0/1
    notify_email: Optional[int] = None        # 邮件提醒 0/1
    notify_wechat: Optional[int] = None       # 微信推送 0/1
    notify_inapp_sound: Optional[int] = None  # 站内信铃声 0/1
    notify_important_only: Optional[int] = None  # 仅重要通知 0/1
    pay_confirm_enable: Optional[int] = None  # 消费二次确认 0/1
    auto_recharge_enable: Optional[int] = None # 自动续费开关 0/1
    auto_recharge_threshold: Optional[float] = Field(None, ge=0)  # 自动续费触发阈值
    auto_recharge_amount: Optional[float] = Field(None, ge=0)     # 自动续费每次金额
    home_default: Optional[str] = None        # 默认首页：/dashboard 等
    hide_zero_balance: Optional[int] = None   # 隐藏 0 余额子账号 0/1
    decimals: Optional[int] = Field(None, ge=0, le=8)  # 金额小数位数


class PayPwdSetReq(BaseModel):
    password: str = Field(..., min_length=6, max_length=32)
    old_password: Optional[str] = None


class BindingSendReq(BaseModel):
    channel: str = Field(..., pattern=r"^(email|phone|wechat|qq)$")
    target: Optional[str] = None
    code: Optional[str] = None  # 提交验证时使用


_PHONE_RE = re.compile(r"^1[3-9]\d{9}$")


def _build_settings_from_row(row: Dict[str, Any]) -> Dict[str, Any]:
    """从 users 行聚合基础列 + settings_json 内字段为 settings 字典"""
    try:
        extra = json.loads(row.get("settings_json") or "{}")
    except Exception:
        extra = {}
    def pick_int(k, default=0):
        v = row.get(k, default)
        if v is None: return default
        try: return int(v)
        except Exception: return default
    settings = {
        # ---- 显示 / 操作偏好 ----
        "lang": row.get("lang") or extra.get("lang") or "zh-CN",
        "theme": row.get("theme") or extra.get("theme") or "light",
        "timezone": row.get("timezone") or extra.get("timezone") or "Asia/Shanghai",
        "density": row.get("density") or extra.get("density") or "default",
        "pageSize": int(row.get("page_size") or extra.get("page_size") or 20),
        "sidebarCollapsed": bool(pick_int("sidebar_collapsed")),
        "currency": row.get("currency") or extra.get("currency") or "CNY",
        "decimals": int(row.get("decimals") or extra.get("decimals") or 2),
        "homeDefault": extra.get("home_default") or "/dashboard",
        "hideZeroBalance": bool(extra.get("hide_zero_balance", 0)),
        # ---- 通知渠道 ----
        "notifySms": bool(extra.get("notify_sms", 0)),
        "notifyEmail": bool(extra.get("notify_email", 1)),
        "notifyWechat": bool(extra.get("notify_wechat", 0)),
        "notifyInappSound": bool(extra.get("notify_inapp_sound", 1)),
        "notifyImportantOnly": bool(extra.get("notify_important_only", 0)),
        # ---- 资金安全 ----
        "payConfirmEnable": bool(extra.get("pay_confirm_enable", 1)),
        "autoRechargeEnable": bool(extra.get("auto_recharge_enable", 0)),
        "autoRechargeThreshold": float(extra.get("auto_recharge_threshold") or 100),
        "autoRechargeAmount": float(extra.get("auto_recharge_amount") or 500),
    }
    return settings


def _merge_and_save_settings(user, req: SettingsUpdateReq):
    """合并 settings_json 并保存到 users 表。返回合并后 settings 字典。"""
    uid = uid_int(user)
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
        if not row:
            return fail("用户不存在")
        try:
            extra = json.loads(row.get("settings_json") or "{}")
        except Exception:
            extra = {}

        base_columns = {}
        col_map = {
            "lang": req.lang, "theme": req.theme, "timezone": req.timezone,
            "density": req.density, "page_size": req.page_size,
            "sidebar_collapsed": req.sidebar_collapsed, "currency": req.currency,
            "decimals": req.decimals,
        }
        for k, v in col_map.items():
            if v is not None:
                base_columns[k] = v

        extra_keys_map = {
            "notify_sms": req.notify_sms, "notify_email": req.notify_email,
            "notify_wechat": req.notify_wechat,
            "notify_inapp_sound": req.notify_inapp_sound,
            "notify_important_only": req.notify_important_only,
            "pay_confirm_enable": req.pay_confirm_enable,
            "auto_recharge_enable": req.auto_recharge_enable,
            "auto_recharge_threshold": req.auto_recharge_threshold,
            "auto_recharge_amount": req.auto_recharge_amount,
            "home_default": req.home_default,
            "hide_zero_balance": req.hide_zero_balance,
        }
        changed_any = False
        for k, v in extra_keys_map.items():
            if v is not None and extra.get(k) != v:
                extra[k] = v if not isinstance(v, bool) else (1 if v else 0)
                changed_any = True
        if base_columns or changed_any:
            sets, params = [], []
            for k, v in base_columns.items():
                sets.append(f"{k}=?")
                params.append(v)
            new_json = json.dumps(extra, ensure_ascii=False)
            sets.append("settings_json=?")
            params.append(new_json)
            sets.append("updated_at=datetime('now','localtime')")
            params.append(uid)
            conn.execute(f"UPDATE users SET {','.join(sets)} WHERE id=?", params)
            row = conn.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    return _build_settings_from_row(dict(row))


@router.post("/register")
def register(req: RegisterReq):
    if not valid_username(req.username):
        return fail("用户名格式错误（3-20位字母数字下划线）")
    if not valid_email(req.email):
        return fail("邮箱格式错误")
    with get_conn() as conn:
        exists = conn.execute(
            "SELECT id FROM users WHERE username=? OR email=?", (req.username, req.email)
        ).fetchone()
        if exists:
            return fail("用户名或邮箱已被使用")
        uid = conn.execute(
            """INSERT INTO users (username, email, phone, wechat, qq, password_hash, balance, status)
               VALUES (?,?,?,?,?,?,?, 'active')""",
            (req.username, req.email, req.phone, req.wechat, req.qq,
             hash_password(req.password), settings.INITIAL_BALANCE),
        ).lastrowid
        conn.execute(
            "INSERT OR IGNORE INTO user_roles (user_id, role_code) VALUES (?,?)",
            (uid, settings.DEFAULT_ROLE),
        )
    return ok({"id": uid}, "注册成功，欢迎加入！您的初始余额为 ¥{:.2f}".format(float(settings.INITIAL_BALANCE)))


@router.post("/login")
def login(req: LoginReq, request: Request):
    if not req.username or not req.password:
        return fail("请输入用户名和密码")
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent")
    with get_conn() as conn:
        user_row = conn.execute(
            "SELECT * FROM users WHERE username=? OR email=?", (req.username, req.username)
        ).fetchone()
        if not user_row:
            audit_login(None, ip=ip, ua=ua, ok=False, summary=f"登录失败：用户名 {req.username} 不存在")
            return fail("用户名或密码错误")
        if user_row["status"] != "active":
            audit_login(user_row, ip=ip, ua=ua, ok=False, summary=f"登录失败：账号已被禁用（status={user_row['status']}）")
            return fail("账号已被禁用")
        if not verify_password(req.password, user_row["password_hash"]):
            audit_login(user_row, ip=ip, ua=ua, ok=False, summary="登录失败：密码错误")
            return fail("用户名或密码错误")
        conn.execute(
            "UPDATE users SET last_login_at = datetime('now','localtime') WHERE id=?",
            (user_row["id"],),
        )
    audit_login(user_row, ip=ip, ua=ua, ok=True, summary="登录成功")
    user = dict(user_row)
    roles, role_names, permissions = get_user_roles_perms(user["id"])
    token = issue_token(user["id"], user["username"], roles, permissions)
    return ok({
        "token": token,
        "accessToken": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "phone": user.get("phone"),
            "wechat": user.get("wechat"),
            "qq": user.get("qq"),
            "balance": f"{float(user['balance']):.2f}",
            "status": user["status"],
            "createdAt": user.get("created_at"),
            "lastLoginAt": user.get("last_login_at"),
        },
        "roles": roles,
        "roleNames": role_names,
        "permissions": permissions,
    }, "登录成功")


@router.post("/logout")
def logout(user=Depends(get_current_user)):
    audit_logout(user, summary="主动登出")
    return ok(None, "已退出")


@router.get("/profile")
def profile(user=Depends(get_current_user)):
    row = user
    try:
        settings = _build_settings_from_row(row)
    except Exception:
        settings = _build_settings_from_row({})
    bindings = {
        "email": {"value": row.get("email"), "verified": bool(row.get("email_verified"))},
        "phone": {"value": row.get("phone"), "verified": bool(row.get("phone_verified"))},
        "wechat": {"value": row.get("wechat"), "verified": bool(row.get("wechat") and row.get("phone_verified"))},
        "qq": {"value": row.get("qq"), "verified": bool(row.get("qq") and row.get("phone_verified"))},
    }
    safety = {
        "apiKey": bool(row.get("api_key")),
        "payPassword": bool(row.get("pay_pwd_hash")),
        "totpEnabled": bool(row.get("totp_enabled")),
        "lastPwdChangedAt": row.get("last_pwd_changed_at"),
    }
    return ok({
        "user": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "phone": user.get("phone"),
            "wechat": user.get("wechat"),
            "qq": user.get("qq"),
            "balance": f"{float(user['balance']):.2f}",
            "status": user["status"],
            "apiKey": user.get("api_key"),
            "lastLoginAt": user.get("last_login_at"),
            "createdAt": user.get("created_at"),
            "currency": settings.get("currency") or "CNY",
        },
        "roles": user["roles"],
        "roleNames": user["role_names"],
        "permissions": user["permissions"],
        "settings": settings,
        "bindings": bindings,
        "safety": safety,
    })


@router.put("/profile")
def update_profile(req: ProfileUpdateReq, user=Depends(get_current_user)):
    changed_fields = {k: getattr(req, k, None) for k in ("email", "phone", "wechat", "qq") if getattr(req, k, None) is not None}
    if not changed_fields:
        return ok(None, "无变更")
    with get_conn() as conn:
        old_row = conn.execute(
            "SELECT email, phone, wechat, qq FROM users WHERE id=?", (user["id"],)
        ).fetchone()
        fields, params = [], []
        for k, v in changed_fields.items():
            fields.append(f"{k}=?")
            params.append(v)
        if "email=?" in fields:
            e = req.email
            if not valid_email(e):
                return fail("邮箱格式错误")
            ex = conn.execute("SELECT id FROM users WHERE email=? AND id<>?", (e, user["id"])).fetchone()
            if ex:
                return fail("该邮箱已被他人使用")
        params.append(user["id"])
        fields.append("updated_at=datetime('now','localtime')")
        conn.execute(f"UPDATE users SET {','.join(fields)} WHERE id=?", params)
    audit_update_profile(
        user,
        old=dict(old_row) if old_row else None,
        new=changed_fields,
        summary=f"更新个人资料字段：{','.join(changed_fields.keys())}",
    )
    return ok(None, "个人资料已更新")


@router.put("/password")
def change_password(req: ChangePwdReq, user=Depends(get_current_user)):
    if not verify_password(req.old, user["password_hash"]):
        audit_change_pwd(user, ok=False, summary="改密失败：原密码错误")
        return fail("原密码错误")
    with get_conn() as conn:
        conn.execute(
            "UPDATE users SET password_hash=?, last_pwd_changed_at=datetime('now','localtime'), updated_at=datetime('now','localtime') WHERE id=?",
            (hash_password(req.password), user["id"]),
        )
    audit_change_pwd(user, ok=True, summary="改密成功")
    return ok(None, "密码已更新")


@router.post("/api-key/reset")
def reset_api_key(user=Depends(require_permission("developer:key")), request: Request = None):
    """重置个人 API Key（需要 developer:key 权限；超管默认放行）"""
    new_key = "mk_" + secrets.token_urlsafe(32)
    with get_conn() as conn:
        old_row = conn.execute("SELECT api_key FROM users WHERE id=?", (user["id"],)).fetchone()
        conn.execute(
            "UPDATE users SET api_key=?, updated_at=datetime('now','localtime') WHERE id=?",
            (new_key, user["id"]),
        )
    audit_reset_api_key(
        user,
        old={"api_key": (old_row["api_key"][:8] + "***") if old_row and old_row["api_key"] else None},
        new={"api_key": new_key[:8] + "***"},
        summary="API Key 重置（全量令牌仅显示一次）",
        ip=request.client.host if request and request.client else None,
        ua=request.headers.get("user-agent") if request else None,
    )
    return ok({"apiKey": new_key}, "API Key 已重置，请妥善保存，仅显示一次")


# ============================================================
#  个人设置中心：偏好 / 显示 / 通知
# ============================================================

@router.get("/settings")
def get_settings(user=Depends(get_current_user)):
    return ok(_build_settings_from_row(user))


@router.put("/settings")
def update_settings(req: SettingsUpdateReq, user=Depends(get_current_user), request: Request = None):
    merged = _merge_and_save_settings(user, req)
    if isinstance(merged, dict) and "code" in merged and merged["code"] != 0:
        return merged
    write_audit(
        user, action="profile_update", level="low", resource_type="settings",
        ip=request.client.host if request and request.client else None,
        ua=request.headers.get("user-agent") if request else None,
        summary="更新个人偏好与设置",
        new=req.model_dump(exclude_none=True),
    )
    return ok(merged, "已保存设置")


# ============================================================
#  支付密码
# ============================================================

@router.post("/pay-password")
def set_pay_password(req: PayPwdSetReq, user=Depends(get_current_user), request: Request = None):
    uid = uid_int(user)
    with get_conn() as conn:
        row = conn.execute("SELECT pay_pwd_hash FROM users WHERE id=?", (uid,)).fetchone()
        old_hash = (row["pay_pwd_hash"] or None) if row else None
        if old_hash:
            if not req.old_password:
                return fail("已设置支付密码，请输入原支付密码进行修改")
            if not verify_password(req.old_password, old_hash):
                write_audit(user, action="password_change", level="high", resource_type="pay_password",
                            ok=False, ip=request.client.host if request and request.client else None,
                            ua=request.headers.get("user-agent") if request else None,
                            summary="支付密码修改失败：原密码错误")
                return fail("原支付密码错误")
        conn.execute(
            "UPDATE users SET pay_pwd_hash=?, updated_at=datetime('now','localtime') WHERE id=?",
            (hash_password(req.password), uid),
        )
    write_audit(user, action="password_change", level="high", resource_type="pay_password",
                ok=True, ip=request.client.host if request and request.client else None,
                ua=request.headers.get("user-agent") if request else None,
                summary=("修改" if old_hash else "首次设置") + "支付密码")
    return ok(None, "支付密码" + ("修改成功" if old_hash else "设置成功"))


# ============================================================
#  绑定状态 & 验证（模拟短信/邮件 OTP：CODE000000 为万用测试验证码）
# ============================================================

@router.get("/bindings")
def get_bindings(user=Depends(get_current_user)):
    bindings = {
        "email": {"value": user.get("email"), "verified": bool(user.get("email_verified"))},
        "phone": {"value": user.get("phone"), "verified": bool(user.get("phone_verified"))},
        "wechat": {"value": user.get("wechat"), "verified": bool(user.get("wechat"))},
        "qq": {"value": user.get("qq"), "verified": bool(user.get("qq"))},
        "totp": {"enabled": bool(user.get("totp_enabled"))},
        "payPassword": {"enabled": bool(user.get("pay_pwd_hash"))},
        "apiKey": {"enabled": bool(user.get("api_key"))},
    }
    return ok(bindings)


@router.post("/bindings/send")
def send_binding_code(req: BindingSendReq, user=Depends(get_current_user), request: Request = None):
    """模拟发送验证码；真实环境接短信/邮件/公众号平台。此处仅写入验证占位记录，成功即提示。"""
    target = (req.target or "").strip()
    if req.channel == "email":
        if target and not valid_email(target):
            return fail("邮箱格式错误")
    elif req.channel == "phone":
        if target and not _PHONE_RE.match(target):
            return fail("手机号格式错误")
    elif req.channel == "wechat":
        if not target:
            target = user.get("wechat") or ""
        if not target:
            return fail("请提供微信号或先在基本资料中填写微信号")
    elif req.channel == "qq":
        if not target:
            target = user.get("qq") or ""
        if not target:
            return fail("请提供 QQ 号或先在基本资料中填写 QQ 号")
        if not re.match(r"^[1-9]\d{4,11}$", target):
            return fail("QQ 号格式错误（5-12 位数字）")
    else:
        return fail("不支持的渠道")
    write_audit(user, action="profile_update", level="low", resource_type=f"binding_{req.channel}",
                summary=f"发送 {req.channel} 绑定验证码（target={target[:3]}***）",
                ip=request.client.host if request and request.client else None,
                ua=request.headers.get("user-agent") if request else None)
    return ok({"channel": req.channel, "sent": True, "mock": True,
               "tip": "demo 环境：请使用 CODE000000 作为验证码"},
              f"验证码已发送至 {'您的' + req.channel}（演示验证码：CODE000000）")


@router.post("/bindings/verify")
def verify_binding(req: BindingSendReq, user=Depends(get_current_user), request: Request = None):
    """验证并绑定渠道；同时可绑定新 target（若提供）。demo CODE000000 通过。"""
    uid = uid_int(user)
    target = (req.target or "").strip()
    code = (req.code or "").strip()
    if code != "CODE000000":
        return fail("验证码错误（演示环境正确验证码：CODE000000）")
    updates, params = [], []
    if req.channel == "email":
        if target:
            if not valid_email(target):
                return fail("邮箱格式错误")
            with get_conn() as conn:
                dup = conn.execute("SELECT id FROM users WHERE email=? AND id<>?", (target, uid)).fetchone()
                if dup: return fail("邮箱已被其他账号使用")
            updates.append("email=?"); params.append(target)
        updates.append("email_verified=?"); params.append(1)
    elif req.channel == "phone":
        if target:
            if not _PHONE_RE.match(target):
                return fail("手机号格式错误")
            with get_conn() as conn:
                dup = conn.execute("SELECT id FROM users WHERE phone=? AND id<>?", (target, uid)).fetchone()
                if dup: return fail("手机号已被其他账号使用")
            updates.append("phone=?"); params.append(target)
        updates.append("phone_verified=?"); params.append(1)
    elif req.channel == "wechat":
        if not target:
            target = user.get("wechat") or ""
        if not target:
            return fail("请提供微信号")
        updates.append("wechat=?"); params.append(target)
    elif req.channel == "qq":
        if not target:
            target = user.get("qq") or ""
        if not target:
            return fail("请提供 QQ 号")
        updates.append("qq=?"); params.append(target)
    else:
        return fail("不支持的渠道")
    updates.append("updated_at=datetime('now','localtime')")
    params.append(uid)
    with get_conn() as conn:
        conn.execute(f"UPDATE users SET {','.join(updates)} WHERE id=?", params)
    write_audit(user, action="profile_update", level="low", resource_type=f"binding_{req.channel}",
                ok=True, ip=request.client.host if request and request.client else None,
                ua=request.headers.get("user-agent") if request else None,
                summary=f"验证并绑定 {req.channel}（target={target[:3]}***）")
    return ok(None, f"{req.channel} 绑定成功")


# ============================================================
#  登录安全：最近登录记录（直接从 audit_logs 取 action=auth_login 成功的）
# ============================================================

@router.get("/login-records")
def list_login_records(user=Depends(get_current_user), page: int = 1, page_size: int = 10):
    uid = uid_int(user)
    page = max(1, int(page or 1))
    page_size = min(50, max(5, int(page_size or 10)))
    limit = page_size
    offset = (page - 1) * page_size
    with get_conn() as conn:
        total = conn.execute(
            "SELECT COUNT(*) c FROM audit_logs WHERE user_id=? AND action=? AND success=1",
            (uid, "auth_login"),
        ).fetchone()["c"]
        rows = conn.execute(
            "SELECT id, ip, user_agent, created_at, summary FROM audit_logs "
            "WHERE user_id=? AND action=? AND success=1 "
            "ORDER BY id DESC LIMIT ? OFFSET ?",
            (uid, "auth_login", limit, offset),
        ).fetchall()
    items = []
    for r in rows:
        ua = r["user_agent"] or ""
        device = "Unknown"
        if ua:
            if "Mobile" in ua or "iPhone" in ua or "Android" in ua: device = "Mobile"
            elif "Windows" in ua: device = "Windows"
            elif "Mac" in ua: device = "macOS"
            elif "Linux" in ua: device = "Linux"
        items.append({
            "id": r["id"],
            "ip": r["ip"] or "unknown",
            "device": device,
            "userAgent": ua,
            "summary": r["summary"],
            "createdAt": r["created_at"],
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": items})
