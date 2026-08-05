"""
交易流水查询接口
支持：多维度筛选（用户ID、交易类型、时间范围、订单/支付关联）、分页、用户隔离
数据来源：transactions 表 + transfers 表（资金划转）统一视图
"""
from typing import Optional
from fastapi import APIRouter, Depends, Query

from core.database import get_conn
from core.security import get_current_user, require_permission, scope_uid, uid_int

router = APIRouter(prefix="/transactions", tags=["交易流水"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


TX_TYPE_LABELS = {
    "recharge": "充值",
    "order_pay": "订单支付",
    "order_refund": "订单退款",
    "transfer_out": "资金划出",
    "transfer_in": "资金划入",
    "coupon_rebate": "优惠券返利",
    "affiliate_commission": "分销佣金",
    "system_adjust": "系统调整",
    "daily_fee": "日扣费",
    "sub_transfer_out": "子账号划转出",
    "sub_transfer_in": "子账号划转进",
}


@router.get("")
def transactions_list(
    type: Optional[str] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    keyword: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    all: Optional[str] = None,
    user=Depends(require_permission("transactions:view")),
):
    uid = scope_uid(user, all)
    wh, params = [], []
    if uid is not None:
        wh.append("t.user_id = ?")
        params.append(uid)
    if type:
        type_list = [t.strip() for t in type.split(",") if t.strip()]
        if len(type_list) == 1:
            wh.append("t.type = ?")
            params.append(type_list[0])
        elif len(type_list) > 1:
            placeholders = ",".join(["?"] * len(type_list))
            wh.append(f"t.type IN ({placeholders})")
            params.extend(type_list)
    if start:
        wh.append("t.created_at >= ?")
        params.append(start)
    if end:
        wh.append("t.created_at <= ?")
        params.append(end + " 23:59:59")
    if keyword:
        wh.append("(t.remark LIKE ? OR EXISTS (SELECT 1 FROM orders o WHERE o.id = t.order_id AND o.order_no LIKE ?))")
        kw = f"%{keyword}%"
        params.extend([kw, kw])
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM transactions t {where}", params).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT t.*,
                       o.order_no,
                       p.pay_no, p.channel
                  FROM transactions t
             LEFT JOIN orders o ON o.id = t.order_id
             LEFT JOIN payments p ON p.id = t.payment_id
                  {where}
              ORDER BY t.id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "id": rd["id"],
            "userId": rd["user_id"],
            "type": rd["type"],
            "typeLabel": TX_TYPE_LABELS.get(rd["type"], rd["type"]),
            "amount": f"{float(rd['amount']):.2f}",
            "amountNum": float(rd["amount"]),
            "balanceBefore": f"{float(rd['balance_before'] or 0):.2f}",
            "balanceAfter": f"{float(rd['balance_after'] or 0):.2f}",
            "orderId": rd.get("order_id"),
            "orderNo": rd.get("order_no"),
            "payNo": rd.get("pay_no"),
            "payChannel": rd.get("channel"),
            "remark": rd.get("remark"),
            "createdAt": rd["created_at"],
        })
    return ok({
        "total": total,
        "page": page,
        "pageSize": page_size,
        "list": list_,
    })


@router.get("/summary")
def transactions_summary(
    type: Optional[str] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    all: Optional[str] = None,
    user=Depends(require_permission("transactions:view")),
):
    uid = scope_uid(user, all)
    wh, params = [], []
    if uid is not None:
        wh.append("t.user_id = ?")
        params.append(uid)
    if type:
        type_list = [t.strip() for t in type.split(",") if t.strip()]
        if len(type_list) == 1:
            wh.append("t.type = ?")
            params.append(type_list[0])
        elif len(type_list) > 1:
            placeholders = ",".join(["?"] * len(type_list))
            wh.append(f"t.type IN ({placeholders})")
            params.extend(type_list)
    if start:
        wh.append("t.created_at >= ?")
        params.append(start)
    if end:
        wh.append("t.created_at <= ?")
        params.append(end + " 23:59:59")
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total_income = conn.execute(
            f"SELECT COALESCE(SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END),0) s FROM transactions t {where}",
            params,
        ).fetchone()["s"]
        total_expense = conn.execute(
            f"SELECT COALESCE(SUM(CASE WHEN t.amount < 0 THEN ABS(t.amount) ELSE 0 END),0) s FROM transactions t {where}",
            params,
        ).fetchone()["s"]
        count = conn.execute(f"SELECT COUNT(*) c FROM transactions t {where}", params).fetchone()["c"]
    return ok({
        "totalIncome": f"{float(total_income):.2f}",
        "totalExpense": f"{float(total_expense):.2f}",
        "netFlow": f"{float(total_income) - float(total_expense):.2f}",
        "count": count,
    })
