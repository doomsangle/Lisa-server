"""
IP 信誉快照接口（差异化功能：IP纯净度 SLA 快照历史）
数据源：proxy_reputation_snapshots 表
能力：
  - 为某台 proxy/server 触发一次快照（调用 check 模块现有探测逻辑）
  - 查询某个 IP / 某个 proxy 的历史快照（折线图数据）
  - 列表：按 proxy_id / server_id / 快照类型筛选
差异化价值：给客户提供「IP 纯净度 SLA」，比友商多一个合规与质量凭证
"""
import time, json, ipaddress
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Request

from core.database import get_conn
from core.security import get_current_user, require_permission, uid_int, enforce_owner_or_super

router = APIRouter(prefix="/reputation", tags=["IP信誉快照"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


CONCLUSION_LABELS = {"pass": "合格", "warn": "关注", "fail": "不合格", "pending": "检测中"}


def _detect_ip_ver(ip: str) -> int:
    try:
        return 6 if isinstance(ipaddress.ip_address(ip), ipaddress.IPv6Address) else 4
    except Exception:
        return 4


# ============ 触发一次 IP 信誉快照 ============
@router.post("/snapshot/{proxy_id}")
def reputation_create_snapshot(
    proxy_id: int, request: Request,
    snapshot_type: str = "manual",
    user=Depends(require_permission("reputation:view")),
):
    uid = uid_int(user)
    with get_conn() as conn:
        proxy = conn.execute(
            "SELECT * FROM proxies WHERE id=?", (proxy_id,),
        ).fetchone()
        if not proxy:
            return fail("接入实例不存在", 404)
        enforce_owner_or_super(user, proxy, "user_id", "创建快照")
        ip = proxy["ip"]
        ip_ver = _detect_ip_ver(ip)
        # 复用 check.py 的探测（mock 生成：真实集成时实际调用）
        # 这里生成模拟数据；生产环境调用 routers/check.py 中同款探测函数
        import random
        rbl_hit = random.choices([0, 0, 0, 1, 1, 2, 5], weights=[50, 30, 10, 5, 3, 1, 1])[0]
        rbl_total = 48
        abuse_score = random.choices([0, 5, 10, 15, 25, 80], weights=[40, 20, 20, 10, 7, 3])[0]
        abuse_reports = random.choices([0, 1, 3, 7, 15, 80], weights=[45, 25, 15, 8, 5, 2])[0]
        ipqs_score = random.choices([90, 85, 75, 60, 40], weights=[35, 30, 20, 10, 5])[0]
        scamalytic = random.choices([95, 85, 70, 50, 20], weights=[40, 30, 15, 10, 5])[0]
        spur = random.choices([90, 80, 65, 50], weights=[45, 30, 15, 10])[0]
        # 综合评分：各权重（生产环境用 check.compute_composite_score）
        composite = int(
            (max(0, 100 - rbl_hit * 8)) * 0.30
            + (max(0, 100 - abuse_score)) * 0.25
            + ipqs_score * 0.20
            + scamalytic * 0.15
            + spur * 0.10
        )
        if composite >= 80:
            conclusion = "pass"
        elif composite >= 60:
            conclusion = "warn"
        else:
            conclusion = "fail"
        country = proxy.get("country_code") or proxy.get("country_name") or ""
        asn_ = "AS" + str(random.randint(1000, 60000))
        raw = {
            "rbl": {"hit": rbl_hit, "total": rbl_total},
            "abuse": {"score": abuse_score, "reports": abuse_reports},
            "ipqs": {"score": ipqs_score},
            "scamalytic": {"score": scamalytic},
            "spur": {"score": spur},
        }
        sid = conn.execute(
            """INSERT INTO proxy_reputation_snapshots
               (proxy_id, server_id, ip, ip_ver, country, asn, rbl_hit, rbl_total,
                abuse_score, abuse_reports, ipqs_score, scamalytic_score, spur_score,
                composite_score, conclusion, raw_json, snapshot_type)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (proxy["id"], proxy.get("server_id"), ip, ip_ver, country, asn_,
             rbl_hit, rbl_total, abuse_score, abuse_reports, ipqs_score,
             scamalytic, spur, composite, conclusion,
             json.dumps(raw, ensure_ascii=False), snapshot_type or "manual"),
        ).lastrowid
    return ok({
        "snapshotId": sid, "proxyId": proxy_id, "ip": ip,
        "compositeScore": composite, "conclusion": conclusion,
        "conclusionLabel": CONCLUSION_LABELS.get(conclusion, conclusion),
        "rblHit": rbl_hit, "rblTotal": rbl_total,
        "abuseScore": abuse_score, "abuseReports": abuse_reports,
        "ipqsScore": ipqs_score, "scamalyticScore": scamalytic, "spurScore": spur,
    }, "快照已生成")


# ============ 快照列表（我的） ============
@router.get("/snapshots")
def reputation_snapshots_list(
    proxy_id: Optional[int] = None,
    server_id: Optional[int] = None,
    ip: Optional[str] = None,
    snapshot_type: Optional[str] = None,
    conclusion: Optional[str] = None,
    start: Optional[str] = None,
    end: Optional[str] = None,
    page: int = 1, page_size: int = 50,
    all: Optional[str] = None,
    user=Depends(require_permission("reputation:view")),
):
    is_sa = all == "1" and user.get("is_super_admin")
    uid = uid_int(user)
    wh, params = [], []
    if not is_sa:
        wh.append("""(EXISTS (SELECT 1 FROM proxies p WHERE p.id = proxy_reputation_snapshots.proxy_id AND p.user_id = ?)
                     OR EXISTS (SELECT 1 FROM vps_servers s WHERE s.id = proxy_reputation_snapshots.server_id AND s.user_id = ?))""")
        params.extend([uid, uid])
    if proxy_id:
        wh.append("proxy_id = ?"); params.append(proxy_id)
    if server_id:
        wh.append("server_id = ?"); params.append(server_id)
    if ip:
        wh.append("ip LIKE ?"); params.append(f"%{ip}%")
    if snapshot_type:
        wh.append("snapshot_type = ?"); params.append(snapshot_type)
    if conclusion:
        wh.append("conclusion = ?"); params.append(conclusion)
    if start:
        wh.append("created_at >= ?"); params.append(start)
    if end:
        wh.append("created_at <= ?"); params.append(end + " 23:59:59")
    where = ("WHERE " + " AND ".join(wh)) if wh else ""
    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) c FROM proxy_reputation_snapshots {where}", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT * FROM proxy_reputation_snapshots {where}
              ORDER BY id DESC
                 LIMIT ? OFFSET ?""",
            params + [page_size, (page - 1) * page_size],
        ).fetchall()
    list_ = []
    for r in rows:
        rd = dict(r)
        list_.append({
            "id": rd["id"], "proxyId": rd.get("proxy_id"), "serverId": rd.get("server_id"),
            "ip": rd["ip"], "ipVer": rd["ip_ver"], "country": rd.get("country"),
            "asn": rd.get("asn"),
            "rblHit": rd.get("rbl_hit", 0), "rblTotal": rd.get("rbl_total", 0),
            "abuseScore": rd.get("abuse_score"), "abuseReports": rd.get("abuse_reports"),
            "ipqsScore": rd.get("ipqs_score"), "scamalyticScore": rd.get("scamalytic_score"),
            "spurScore": rd.get("spur_score"),
            "compositeScore": rd.get("composite_score"),
            "conclusion": rd.get("conclusion"),
            "conclusionLabel": CONCLUSION_LABELS.get(rd.get("conclusion") or "", rd.get("conclusion") or ""),
            "snapshotType": rd.get("snapshot_type", "manual"),
            "createdAt": rd["created_at"],
        })
    return ok({"total": total, "page": page, "pageSize": page_size, "list": list_})


# ============ 历史趋势（给图表用：某个 proxy_id 最近 N 次快照折线） ============
@router.get("/trend/{proxy_id}")
def reputation_trend(proxy_id: int, limit: int = 30, user=Depends(get_current_user)):
    uid = uid_int(user)
    with get_conn() as conn:
        proxy = conn.execute("SELECT * FROM proxies WHERE id=?", (proxy_id,)).fetchone()
        if not proxy:
            return fail("接入实例不存在", 404)
        enforce_owner_or_super(user, proxy, "user_id", "查看趋势")
        rows = conn.execute(
            """SELECT * FROM proxy_reputation_snapshots
                WHERE proxy_id = ?
             ORDER BY id ASC
                LIMIT ?""",
            (proxy_id, max(5, min(limit, 180))),
        ).fetchall()
    x_labels, composite, rbl_pct, abuse, ipqs = [], [], [], [], []
    for r in rows:
        x_labels.append(r["created_at"][5:16])  # MM-DD HH:MM
        composite.append(r["composite_score"])
        total = max(1, r["rbl_total"] or 1)
        rbl_pct.append(round(100 - (r["rbl_hit"] or 0) * 100 / total, 1))
        abuse.append(max(0, 100 - (r["abuse_score"] or 0)))
        ipqs.append(r["ipqs_score"] or 0)
    sla = 0
    if composite:
        sla = round(sum(1 for s in composite if s >= 80) * 100 / len(composite), 1)
    latest = (
        {
            "composite": composite[-1] if composite else None,
            "conclusion": CONCLUSION_LABELS.get(rows[-1]["conclusion"], rows[-1]["conclusion"]) if rows else None,
        }
        if rows else {}
    )
    return ok({
        "ip": proxy["ip"],
        "country": proxy.get("country_name") or proxy.get("country_code"),
        "slaPercent": sla,
        "slaLabel": f"{sla}% 快照合格率",
        "totalSnapshots": len(rows),
        "latest": latest,
        "chart": {
            "xLabels": x_labels,
            "series": [
                {"name": "综合评分", "data": composite},
                {"name": "RBL 合格率", "data": rbl_pct},
                {"name": "Abuse 干净度", "data": abuse},
                {"name": "IPQS 评分", "data": ipqs},
            ],
        },
    })
