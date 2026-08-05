"""
优惠券管理接口
- admin 可创建、管理优惠券
- 所有登录用户可查看可用优惠券、兑换（redeem）优惠券
- 优惠券类型：percent 比例折扣 / fixed 固定金额
"""
import time, json, random, string
from typing import Optional, List
from datetime import datetime as _dt
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from core.database import get_conn
from core.security import get_current_user, require_permission, uid_int, require_role
from core.audit import write_audit

router = APIRouter(prefix="/coupons", tags=["优惠券"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


def _gen_code(length=10):
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))


# ============ 可用优惠券列表（用户侧） ============
@router.get("/available")
def coupons_available(user=Depends(get_current_user)):
    uid = uid_int(user)
    now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT c.*,
                      (SELECT COUNT(*) FROM coupon_redemptions r
                        WHERE r.coupon_id = c.id AND r.user_id = ?) redeemed_by_me
                 FROM coupons c
                WHERE c.status = 'active'
                  AND (c.valid_from IS NULL OR c.valid_from <= ?)
                  AND (c.valid_until IS NULL OR c.valid_until >= DATE(?))
                  AND (c.user_scope IN ('all', ?)
                       OR EXISTS (SELECT 1 FROM user_roles ur
                                   WHERE ur.user_id = ? AND ur.role_code = c.user_scope))
             ORDER BY (c.usage_limit IS NULL OR c.usage_count < c.usage_limit) DESC,
                      c.created_at DESC
                LIMIT 100""",
            (uid, now, now, str(uid), uid),
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        used_up = rd["usage_limit"] and (rd["usage_count"] or 0) >= rd["usage_limit"]
        list_.append({
            "id": rd["id"], "code": rd["code"], "name": rd["name"],
            "type": rd["type"], "typeLabel": "满减券" if rd["type"] == "fixed" else "折扣券",
            "value": float(rd["value"]),
            "minOrder": float(rd["min_order"] or 0),
            "maxDiscount": float(rd["max_discount"]) if rd["max_discount"] else None,
            "usageLimit": rd["usage_limit"],
            "usageCount": rd["usage_count"] or 0,
            "appliesTo": rd["applies_to"],
            "validFrom": rd["valid_from"],
            "validUntil": rd["valid_until"],
            "redeemedByMe": (rd.get("redeemed_by_me") or 0) > 0,
            "remaining": None if not rd["usage_limit"] else max(0, rd["usage_limit"] - (rd["usage_count"] or 0)),
            "usedUp": used_up,
            "createdAt": rd["created_at"],
        })
    return ok({"list": list_, "total": len(list_)})


# ============ 我的优惠券（已兑换/历史） ============
@router.get("/mine")
def coupons_mine(
    status: Optional[str] = None,  # unused/used/expired
    page: int = 1, page_size: int = 50,
    user=Depends(get_current_user),
):
    uid = uid_int(user)
    today = time.strftime("%Y-%m-%d", time.localtime())
    with get_conn() as conn:
        base_sql = f"""
            SELECT r.id redemption_id, r.created_at redeemed_at,
                   r.discount_amount, r.original_amount, r.final_amount, r.order_id,
                   c.*
              FROM coupon_redemptions r
              JOIN coupons c ON c.id = r.coupon_id
             WHERE r.user_id = ?
        """
        where = ""
        params = [uid]
        if status == "unused":
            where = " AND (r.order_id IS NULL) AND (c.valid_until IS NULL OR c.valid_until >= ?)"
            params.append(today)
        elif status == "used":
            where = " AND r.order_id IS NOT NULL"
        elif status == "expired":
            where = " AND (r.order_id IS NULL) AND c.valid_until IS NOT NULL AND c.valid_until < ?"
            params.append(today)
        total = conn.execute(
            f"SELECT COUNT(*) c FROM ({base_sql + where})", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"""{base_sql + where}
            ORDER BY r.id DESC
               LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "redemptionId": rd["redemption_id"], "redeemedAt": rd["redeemed_at"],
            "discountAmount": float(rd["discount_amount"] or 0),
            "orderId": rd.get("order_id"),
            "code": rd["code"], "name": rd["name"], "type": rd["type"],
            "value": float(rd["value"]),
            "minOrder": float(rd["min_order"] or 0),
            "maxDiscount": float(rd["max_discount"]) if rd["max_discount"] else None,
            "validFrom": rd["valid_from"],
            "validUntil": rd["valid_until"],
            "status": "used" if rd.get("order_id") else (
                "expired" if rd["valid_until"] and rd["valid_until"] < today else "unused"
            ),
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


# ============ 管理员：优惠券列表 ============
@router.get("")
def coupons_admin_list(
    status: Optional[str] = None,
    keyword: Optional[str] = None,
    page: int = 1, page_size: int = 50,
    user=Depends(require_permission("coupons:view")),
):
    can_manage = user.get("is_super_admin") or ("coupons:manage" in user["permissions"])
    wh, params = [], []
    if not can_manage:
        wh.append("1=0")  # 无管理权限看空列表（用户侧走 available/mine）
    if status:
        wh.append("status = ?"); params.append(status)
    if keyword:
        wh.append("(code LIKE ? OR name LIKE ?)")
        kw = f"%{keyword}%"
        params.extend([kw, kw])
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM coupons {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT c.*, u.username created_by_name
                  FROM coupons c
             LEFT JOIN users u ON u.id = c.created_by
                {where}
              ORDER BY c.id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "id": rd["id"], "code": rd["code"], "name": rd["name"],
            "type": rd["type"], "value": float(rd["value"]),
            "minOrder": float(rd["min_order"] or 0),
            "maxDiscount": float(rd["max_discount"]) if rd["max_discount"] else None,
            "usageLimit": rd["usage_limit"], "usageCount": rd["usage_count"] or 0,
            "appliesTo": rd["applies_to"], "userScope": rd["user_scope"],
            "validFrom": rd["valid_from"], "validUntil": rd["valid_until"],
            "status": rd["status"], "createdBy": rd.get("created_by_name"),
            "createdAt": rd["created_at"],
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


# ============ 管理员：创建优惠券 ============
class CouponCreateReq(BaseModel):
    name: str = Field(min_length=2, max_length=50)
    type: str = "percent"
    value: float = Field(gt=0)
    min_order: float = 0
    max_discount: Optional[float] = None
    usage_limit: Optional[int] = None
    applies_to: Optional[str] = None
    user_scope: str = "all"
    valid_from: Optional[str] = None
    valid_until: Optional[str] = None
    count: int = Field(1, ge=1, le=100)
    auto_code: bool = True
    code_prefix: Optional[str] = None


@router.post("")
def coupons_create(
    req: CouponCreateReq, request: Request,
    user=Depends(require_permission("coupons:manage")),
):
    if req.type not in ["percent", "fixed"]:
        return fail("优惠券类型必须是 percent(折扣) 或 fixed(满减)")
    if req.type == "percent" and (req.value <= 0 or req.value >= 100):
        return fail("折扣券比例必须在 0-100 之间（不含边界）")
    if req.user_scope not in ["all", "user", "vip", "new", "super_admin", "admin", "finance", "support"]:
        return fail("user_scope 不合法")
    uid = uid_int(user)
    created = []
    with get_conn() as conn:
        for i in range(req.count):
            if req.auto_code:
                prefix = (req.code_prefix or "MC").upper()
                code = f"{prefix}{_gen_code(10 - len(prefix))}" if req.count == 1 else (
                    f"{prefix}{_gen_code(6)}{i+1:03d}"
                )
            else:
                code = req.code_prefix or _gen_code(10)
                code = code.upper()
            # 避免重复
            for _retry in range(5):
                e = conn.execute("SELECT id FROM coupons WHERE code=?", (code,)).fetchone()
                if not e:
                    break
                code = f"{(req.code_prefix or 'MC').upper()}{_gen_code(8)}"
            id_ = conn.execute(
                """INSERT INTO coupons
                   (code, name, type, value, min_order, max_discount, usage_limit,
                    applies_to, user_scope, valid_from, valid_until, status, created_by)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?, 'active', ?)""",
                (code, req.name, req.type, round(float(req.value), 2),
                 round(float(req.min_order or 0), 2),
                 (round(float(req.max_discount), 2) if req.max_discount and req.max_discount > 0 else None),
                 (req.usage_limit if req.usage_limit and req.usage_limit > 0 else None),
                 req.applies_to, req.user_scope, req.valid_from, req.valid_until, uid),
            ).lastrowid
            created.append({"id": id_, "code": code})
    write_audit(user, action="config_change", level="high", resource_type="coupons",
                resource_id="batch", ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"批量创建 {req.count} 张优惠券：{req.name}",
                new=dict(req))
    return ok({"created": created, "total": len(created)}, f"成功创建 {len(created)} 张优惠券")


# ============ 管理员：更新/启停 ============
class CouponUpdateReq(BaseModel):
    name: Optional[str] = None
    status: Optional[str] = None
    usage_limit: Optional[int] = None
    valid_from: Optional[str] = None
    valid_until: Optional[str] = None


@router.put("/{cid}")
def coupons_update(
    cid: int, req: CouponUpdateReq, request: Request,
    user=Depends(require_permission("coupons:manage")),
):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM coupons WHERE id=?", (cid,)).fetchone()
        if not row:
            return fail("优惠券不存在", 404)
        sets, params = [], []
        if req.name:
            sets.append("name = ?"); params.append(req.name)
        if req.status and req.status in ["active", "inactive", "expired"]:
            sets.append("status = ?"); params.append(req.status)
        if req.usage_limit is not None:
            sets.append("usage_limit = ?")
            params.append(req.usage_limit if req.usage_limit > 0 else None)
        if req.valid_from:
            sets.append("valid_from = ?"); params.append(req.valid_from)
        if req.valid_until:
            sets.append("valid_until = ?"); params.append(req.valid_until)
        if sets:
            sets.append("updated_at = datetime('now','localtime')")
            conn.execute(
                f"UPDATE coupons SET {', '.join(sets)} WHERE id=?",
                params + [cid],
            )
    write_audit(user, action="config_change", level="high", resource_type="coupons",
                resource_id=str(cid), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"更新优惠券 #{cid}", new=dict(req))
    return ok(None, "更新成功")


# ============ 兑换优惠券（用户领用） ============
class RedeemReq(BaseModel):
    code: str = Field(min_length=4, max_length=32)


@router.post("/redeem")
def coupons_redeem(
    req: RedeemReq, request: Request,
    user=Depends(require_permission("coupons:redeem")),
):
    code = req.code.strip().upper()
    uid = uid_int(user)
    now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    today = now[:10]
    with get_conn() as conn:
        coupon = conn.execute(
            "SELECT * FROM coupons WHERE code=?", (code,),
        ).fetchone()
        if not coupon:
            return fail("优惠券码不存在")
        if coupon["status"] != "active":
            return fail("该优惠券已停用")
        # 是否已经兑过（同一个用户不能重复领取同一张券）
        exist_red = conn.execute(
            "SELECT id FROM coupon_redemptions WHERE coupon_id=? AND user_id=?",
            (coupon["id"], uid),
        ).fetchone()
        if exist_red:
            return fail("您已经领过该优惠券了")
        if coupon["valid_from"] and _dt.strptime(now, "%Y-%m-%d %H:%M:%S") < _dt.strptime(coupon["valid_from"], "%Y-%m-%d %H:%M:%S"):
            return fail("优惠券尚未生效")
        if coupon["valid_until"] and today > coupon["valid_until"]:
            return fail("优惠券已过期")
        if coupon["usage_limit"] and (coupon["usage_count"] or 0) >= coupon["usage_limit"]:
            return fail("优惠券已被领完")
        # 适用范围校验（简化：user_scope 只做基本判断）
        if coupon["user_scope"] == "new" and False:
            pass  # 预留：可判断是否新用户
        rid = conn.execute(
            "INSERT INTO coupon_redemptions (coupon_id, user_id, code, discount_amount) VALUES (?,?,?,0)",
            (coupon["id"], uid, code),
        ).lastrowid
        conn.execute(
            "UPDATE coupons SET usage_count = usage_count + 1 WHERE id=?",
            (coupon["id"],),
        )
        # 通知
        conn.execute(
            """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
               VALUES (?,'coupon','优惠券领取成功',?,'success','coupon',?)""",
            (uid, f"成功领取：{coupon['name']}（{code}），有效期至 {coupon['valid_until'] or '长期有效'}", str(rid)),
        )
    write_audit(user, action="order_create", level="low", resource_type="coupons",
                resource_id=str(coupon["id"]), ip=request.client.host if request.client else None,
                ua=request.headers.get("user-agent"),
                summary=f"用户领取优惠券 {code}")
    return ok({
        "redemptionId": rid, "couponId": coupon["id"], "code": code,
        "name": coupon["name"], "type": coupon["type"],
    }, "领取成功")
