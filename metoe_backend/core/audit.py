"""
MetoE 合规审计模块（对应 ToS 第 2.3 条 / 隐私政策第 1.1 条第 6 类 audit_logs 表）
————————————————————————————————————————————————————————————————
使用方式：
  from core.audit import write_audit
  write_audit(user, action='change_password', resource_type='users', resource_id=user['id'],
              old={'email':'old@x.com'}, new={'email':'new@x.com'}, ip=request.client.host, ua=request.headers.get('user-agent'))

注意事项：
  · 写审计是「尽力而为」（try/except 吞下所有异常）——绝不能因为写审计失败而影响主业务流程
  · 所有 JSON 字段做长度截断（old_json/new_json 单字段最长 10000 字符），避免 SQLITE_MAX_LENGTH
  · action 枚举见下方 AUDIT_ACTIONS 表，前端 AuditLog.vue opTypes 与之对齐
"""
from __future__ import annotations

import json
from typing import Any, Optional

from .database import get_conn


# 审计动作枚举（前端 AuditLog.vue opTypes 必须一一对应；新增动作须同步更新前后端）
AUDIT_ACTIONS = {
    # ===== 账户 & 安全（高/中危） =====
    'register':            {'level': 'low',  'name': '注册账户',       'icon': 'Avatar'},
    'login_success':       {'level': 'low',  'name': '登录成功',       'icon': 'Avatar'},
    'login_fail':          {'level': 'mid',  'name': '登录失败',       'icon': 'Lock'},
    'logout':              {'level': 'low',  'name': '登出账户',       'icon': 'Avatar'},
    'change_password':     {'level': 'high', 'name': '修改登录密码',   'icon': 'Lock'},
    'reset_api_key':       {'level': 'high', 'name': '重置 API Key',   'icon': 'Key'},
    'update_profile':      {'level': 'low',  'name': '更新个人资料',   'icon': 'Avatar'},

    # ===== KYC 合规（高危 — AML/反洗钱） =====
    'kyc_submit':          {'level': 'mid',  'name': '提交实名认证',   'icon': 'CircleCheckFilled'},
    'kyc_approved':        {'level': 'mid',  'name': 'KYC 审核通过',   'icon': 'CircleCheckFilled'},
    'kyc_rejected':        {'level': 'high', 'name': 'KYC 审核拒绝',   'icon': 'Warning'},

    # ===== 财务（高危 — 对账 & 资金追溯） =====
    'finance_recharge':    {'level': 'mid',  'name': '钱包充值',       'icon': 'Wallet'},
    'finance_withdraw':    {'level': 'high', 'name': '提现申请',       'icon': 'Wallet'},
    'finance_withdraw_ok': {'level': 'high', 'name': '提现已打款',     'icon': 'Wallet'},
    'order_create':        {'level': 'low',  'name': '创建订单',       'icon': 'Tickets'},
    'order_refund':        {'level': 'high', 'name': '订单退款',       'icon': 'Tickets'},

    # ===== 资源操作 =====
    'server_create':       {'level': 'low',  'name': '创建服务器',     'icon': 'Connection'},
    'server_op':           {'level': 'mid',  'name': '服务器操作',     'icon': 'Connection'},  # reboot/reinstall/deploy
    'server_delete':       {'level': 'high', 'name': '删除服务器',     'icon': 'Delete'},
    'proxy_purchase':      {'level': 'low',  'name': '购买代理',       'icon': 'Link'},
    'proxy_delete':        {'level': 'mid',  'name': '删除代理',       'icon': 'Delete'},

    # ===== 系统 & 权限（最高危） =====
    'config_change':       {'level': 'high', 'name': '修改全局配置',   'icon': 'Setting'},
    'role_grant':          {'level': 'high', 'name': '授予角色权限',   'icon': 'Key'},
    'role_revoke':         {'level': 'high', 'name': '撤销角色权限',   'icon': 'Key'},
    'user_ban':            {'level': 'high', 'name': '封禁用户',       'icon': 'Lock'},
    'user_unban':          {'level': 'high', 'name': '解封用户',       'icon': 'Lock'},

    # ===== 合规处置（AUP / DMCA / OFAC — ToS 第 2 条） =====
    'aup_warning':         {'level': 'mid',  'name': 'AUP 违规警告',   'icon': 'Warning'},
    'aup_stop_server':     {'level': 'high', 'name': '停机处置',       'icon': 'Delete'},
    'aup_dmca_takedown':   {'level': 'high', 'name': 'DMCA 下架',      'icon': 'Tickets'},
    'ofac_reject':         {'level': 'high', 'name': 'OFAC 拒绝服务',  'icon': 'Lock'},
}


MAX_FIELD_LEN = 10000  # SQLite 单字段安全长度


def _truncate(v: Any, max_len: int = MAX_FIELD_LEN) -> Any:
    """任意值截断到安全长度"""
    if v is None:
        return None
    try:
        s = json.dumps(v, ensure_ascii=False)
    except Exception:
        s = str(v)
    if len(s) > max_len:
        s = s[:max_len] + "...[TRUNCATED]"
    return s


def write_audit(user_or_uid,
                action: str,
                *,
                level: Optional[str] = None,
                resource_type: Optional[str] = None,
                resource_id: Optional[int | str] = None,
                old: Any = None,
                new: Any = None,
                ip: Optional[str] = None,
                ua: Optional[str] = None,
                ok: bool = True,
                summary: Optional[str] = None,
                _conn=None) -> None:
    """写一条审计日志（异常被吞下，保证不影响主流程；可传 conn 复用外层事务）"""
    try:
        # 处理 user_or_uid（既可以是 user dict，也可以是纯 int uid）
        user_id = None
        username = None
        if isinstance(user_or_uid, (int,)):
            user_id = int(user_or_uid)
        elif isinstance(user_or_uid, dict):
            user_id = int(user_or_uid.get('id') or 0) or None
            username = user_or_uid.get('username')
        if not user_id:
            return  # 无用户身份则跳过

        meta = AUDIT_ACTIONS.get(action) or {'level': 'low', 'name': action, 'icon': 'Notebook'}
        level = (level or meta['level'])[:8]

        # 补 summary（如果没传，用通用模板拼一个）
        if summary is None:
            parts = [meta['name']]
            if resource_type:
                parts.append(f"资源[{resource_type}]")
            if resource_id is not None:
                parts.append(f"ID:{resource_id}")
            summary = " ".join(parts)

        def __do(conn):
            conn.execute(
                """INSERT INTO audit_logs
                (user_id, username, action, level, resource_type, resource_id,
                 old_json, new_json, ip, user_agent, success, summary, created_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?, datetime('now','localtime'))""",
                (
                    user_id,
                    (username or '')[:64],
                    action[:64],
                    level[:8],
                    (resource_type or '')[:64],
                    None if resource_id is None else str(resource_id)[:64],
                    _truncate(old),
                    _truncate(new),
                    (ip or '')[:64],
                    (ua or '')[:512],
                    1 if ok else 0,
                    (summary or '')[:500],
                ),
            )

        if _conn is not None:
            __do(_conn)
        else:
            with get_conn() as conn:
                __do(conn)
    except Exception:
        # 审计失败绝不向上冒泡，只静默记录（生产可对接 sentry）
        return


# ---------- 便捷包装函数（供 routes/* 调用，语义更清晰；均透传 kwargs 给 write_audit，支持 old/new/summary/ip/ua/resource_id/resource_type/ok/_conn 等） ----------
def audit_login(user, **kw):
    ok = kw.get('ok', True)
    action = 'login_success' if ok else 'login_fail'
    return write_audit(user, action, **{k:v for k,v in kw.items() if k != 'fail_reason'})

def audit_logout(user, **kw):
    return write_audit(user, 'logout', **kw)

def audit_change_pwd(user, **kw):
    return write_audit(user, 'change_password', **kw)

def audit_reset_api_key(user, **kw):
    return write_audit(user, 'reset_api_key', **kw)

def audit_update_profile(user, **kw):
    return write_audit(user, 'update_profile', **kw)

def audit_config_save(user, **kw):
    return write_audit(user, 'config_change', **kw)

def audit_ban(admin, target_uid, target_name, reason, ip=None, ua=None, ban=True, **kw):
    return write_audit(admin, 'user_ban' if ban else 'user_unban',
                       resource_type='users', resource_id=target_uid,
                       new={'target': target_name, 'reason': reason},
                       ip=ip, ua=ua, **kw)

def audit_payment_success(user, **kw):
    return write_audit(user, 'finance_recharge', **kw)

def audit_order_create(user, **kw):
    return write_audit(user, 'order_create', **kw)

def audit_order_status_change(user, **kw):
    new_status = (kw.get('new') or {}).get('status') if isinstance(kw.get('new'), dict) else None
    action = 'order_refund' if new_status == 'refunded' else 'order_create'
    return write_audit(user, action, **kw)

def audit_server_reboot(user, **kw):
    return write_audit(user, 'server_op', **kw)

def audit_server_reinstall(user, **kw):
    return write_audit(user, 'server_op', **kw)

def audit_server_delete(user, **kw):
    return write_audit(user, 'server_delete', **kw)

def audit_kyc_submit(user, **kw):
    return write_audit(user, 'kyc_submit', **kw)

def audit_kyc_audit(admin, **kw):
    new_status = (kw.get('new') or {}).get('status') if isinstance(kw.get('new'), dict) else None
    if new_status == 'rejected':
        action = 'kyc_rejected'
    elif new_status == 'passed':
        action = 'kyc_approved'
    else:
        action = 'kyc_submit'
    return write_audit(admin, action, **kw)
