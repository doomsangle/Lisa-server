"""系统配置接口：客服信息、站点设置、Lisa主机API凭证、回调域名、支付开关"""
import time
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

from core.database import get_conn
from core.security import require_permission, get_current_user
from core.audit import audit_config_save

router = APIRouter(prefix="/config", tags=["系统配置"])


# ===== 公开接口：客服联系方式 =====
@router.get("/customer-service")
def get_customer_service():
    """公开接口：获取客服联系方式（无需登录，页面顶部/底部/反馈页展示）"""
    keys = [
        "site_name", "cs_wechat", "cs_wechat_qr", "cs_qq", "cs_qq_qr",
        "cs_email", "cs_phone", "cs_work_time", "cs_group_invite",
    ]
    with get_conn() as conn:
        rows = conn.execute(
            f"SELECT key, value, description FROM system_configs WHERE key IN ({','.join('?'*len(keys))})",
            keys,
        ).fetchall()
    data = {r["key"]: r["value"] or "" for r in rows}
    desc = {r["key"]: r["description"] or "" for r in rows}
    return {"code": 200, "message": "ok", "data": {"data": data, "description": desc}}


# ===== 支付渠道开关（公开，页面决定显示哪些支付方式） =====
@router.get("/payment-channels")
def get_payment_channels():
    """
    获取全部可用支付渠道：
    - 余额支付 / 模拟支付 / 支付宝 / 微信 / USDT(TRC20) / PayPal
    - 对 USDT 包含：实时汇率、收款钱包地址、网络类型、过期时长
    - 对 PayPal 包含：沙盒/正式模式、客户端ID、手续费率、结算币种
    """
    enable_keys = [
        "payment_mock_enabled", "payment_alipay_enabled",
        "payment_wechat_enabled", "payment_usdt_enabled", "payment_paypal_enabled",
    ]
    paypal_keys = [
        "paypal_mode", "paypal_client_id", "paypal_currency",
        "paypal_fee_rate", "paypal_fixed_fee_usd",
    ]
    usdt_keys = [
        "usdt_network", "usdt_wallet_address", "usdt_cny_usd_rate",
        "usdt_min_confirm", "usdt_order_expire_min",
    ]
    all_keys = enable_keys + paypal_keys + usdt_keys

    with get_conn() as conn:
        rows = conn.execute(
            f"SELECT key, value FROM system_configs WHERE key IN ({','.join('?'*len(all_keys))})",
            all_keys,
        ).fetchall()
    kv = {r["key"]: r["value"] or "" for r in rows}

    def on(k):
        return kv.get(k, "0") == "1"

    try:
        cny_per_usd = float(kv.get("usdt_cny_usd_rate") or "7.25")
    except Exception:
        cny_per_usd = 7.25
    try:
        pp_fee_rate = float(kv.get("paypal_fee_rate") or "0.044")
        pp_fee_fixed = float(kv.get("paypal_fixed_fee_usd") or "0.3")
    except Exception:
        pp_fee_rate, pp_fee_fixed = 0.044, 0.3

    channels = [
        {"key": "balance", "name": "余额支付", "enabled": True, "icon": "💰",
         "currency": "CNY", "tips": "直接使用账户余额扣款，实时到账，即时部署"},
        {"key": "mock", "name": "模拟支付(测试)", "enabled": on("payment_mock_enabled"),
         "icon": "🧪", "currency": "CNY",
         "tips": "测试模式：点确认即模拟支付成功，适合体验完整下单→部署流程"},
        {"key": "alipay", "name": "支付宝", "enabled": on("payment_alipay_enabled"),
         "icon": "💙", "currency": "CNY", "tips": "推荐国内用户使用，扫码付款实时到账"},
        {"key": "wechat", "name": "微信支付", "enabled": on("payment_wechat_enabled"),
         "icon": "💚", "currency": "CNY", "tips": "微信扫码付款，实时到账"},
        {"key": "usdt", "name": f"USDT({kv.get('usdt_network') or 'TRC20'})",
         "enabled": on("payment_usdt_enabled"), "icon": "💲",
         "currency": "USDT",
         "wallet": {
             "network": kv.get("usdt_network") or "TRC20",
             "address": kv.get("usdt_wallet_address") or "",
             "min_confirm": int(kv.get("usdt_min_confirm") or "1"),
             "expire_min": int(kv.get("usdt_order_expire_min") or "30"),
         },
         "rate": {
             "source": kv.get("usdt_rate_source") or "coinbase",
             "cny_per_usd": cny_per_usd,
             "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
         },
         "tips": "按实时汇率折算为 USDT，务必使用指定网络转账，转错网络无法找回"},
        {"key": "paypal", "name": f"PayPal ({(kv.get('paypal_mode') or 'sandbox').upper()})",
         "enabled": on("payment_paypal_enabled"), "icon": "🟦",
         "currency": kv.get("paypal_currency") or "USD",
         "paypal": {
             "mode": kv.get("paypal_mode") or "sandbox",
             "client_id": kv.get("paypal_client_id") or "",
             "currency": kv.get("paypal_currency") or "USD",
             "fee_rate": pp_fee_rate,
             "fee_fixed_usd": pp_fee_fixed,
         },
         "rate": {
             "source": "paypal_official",
             "cny_per_usd": cny_per_usd,
             "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
         },
         "tips": "支持全球 200+ 国家/地区，Visa/Master/PayPal 余额均可付款，含 4.4%+$0.3 手续费"},
    ]
    return {"code": 200, "message": "ok", "data": channels}


# ===== 管理员：获取全部配置 =====
class ConfigSave(BaseModel):
    items: Dict[str, Any]


@router.get("/all")
def list_all_configs(_user=Depends(require_permission("config:view"))):
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT key, value, description, updated_at FROM system_configs ORDER BY key"
        ).fetchall()
    return {"code": 200, "message": "ok", "data": [dict(r) for r in rows]}


@router.post("/save")
def save_configs(payload: ConfigSave, request: Request, user=Depends(require_permission("config:manage"))):
    with get_conn() as conn:
        # 记录旧值 → 审计追溯
        old_dict = {}
        for k in payload.items.keys():
            r = conn.execute("SELECT value FROM system_configs WHERE key=?", (k,)).fetchone()
            old_dict[k] = r["value"] if r else None
        for k, v in payload.items.items():
            val = "" if v is None else str(v)
            conn.execute(
                """INSERT INTO system_configs (key, value, updated_at) VALUES (?,?,datetime('now','localtime'))
                   ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now','localtime')""",
                (k, val),
            )
    changed_keys = [k for k in payload.items.keys() if str(payload.items[k] if payload.items[k] is not None else "") != str(old_dict.get(k) or "")]
    audit_config_save(
        user,
        old=old_dict,
        new={k: (payload.items[k] if payload.items[k] is not None else "") for k in changed_keys},
        summary=f"系统配置修改：共 {len(changed_keys)} 项（{','.join(changed_keys[:8])}{'...' if len(changed_keys)>8 else ''}）",
        ip=request.client.host if request.client else None,
        ua=request.headers.get("user-agent"),
    )
    return {"code": 200, "message": "系统配置保存成功", "data": None}
