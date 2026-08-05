"""实名认证 KYC 路由：个人/企业提交、状态查询、管理员审核"""
import json
import re
import time
from typing import Optional, List
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel

from core.database import get_conn
from core.security import get_current_user, require_permission
from core.audit import audit_kyc_submit, audit_kyc_audit, write_audit

router = APIRouter(prefix="/verify", tags=["实名认证"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


VALID_STATUS = {"none": "未提交", "pending": "审核中", "passed": "已通过", "rejected": "已驳回"}


def _mask(s, keep_head=0, keep_tail=4, mask_char="*"):
    """脱敏：保留头尾中间打码"""
    if not s or not isinstance(s, str): return ""
    if len(s) <= keep_head + keep_tail: return mask_char * len(s)
    return s[:keep_head] + mask_char * max(1, len(s) - keep_head - keep_tail) + s[-keep_tail:]


def _idcard_valid(idcard: str) -> bool:
    if not idcard: return False
    s = idcard.strip().upper()
    if not re.fullmatch(r"\d{17}[\dX]", s): return False
    # 18位校验位
    w = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
    m = "10X98765432"
    total = sum(int(s[i]) * w[i] for i in range(17))
    return m[total % 11] == s[17]


def _uscc_valid(uscc: str) -> bool:
    """统一社会信用代码：18位字母数字"""
    return bool(re.fullmatch(r"[0-9A-HJ-NPQRTUWXY]{18}", (uscc or "").strip().upper()))


def _mask_row_to_public(d):
    """返回给前端的脱敏结构"""
    if not d: return None
    return {
        "id": d.get("id"),
        "type": d.get("type"),
        "status": d.get("status"),
        "rejectReason": d.get("reject_reason"),
        "name": d.get("name") or "",
        "nameMasked": _mask(d.get("name") or "", 1, 1),
        "idcardMasked": _mask(d.get("idcard") or "", 3, 4),
        "phoneMasked": _mask(d.get("phone") or "", 3, 4),
        "idFrontUrl": d.get("id_front_url") or "",
        "idBackUrl": d.get("id_back_url") or "",
        "faceUrl": d.get("face_url") or "",
        "company": d.get("company") or "",
        "usccMasked": _mask(d.get("uscc") or "", 4, 4),
        "legalName": d.get("legal_name") or "",
        "legalNameMasked": _mask(d.get("legal_name") or "", 1, 1),
        "legalIdcardMasked": _mask(d.get("legal_idcard") or "", 3, 4),
        "bankAccountMasked": _mask(d.get("bank_account") or "", 4, 4),
        "contactEmailMasked": _mask(d.get("contact_email") or "", 2, 4),
        "licenseUrl": d.get("license_url") or "",
        "submittedAt": d.get("submitted_at"),
        "reviewedAt": d.get("reviewed_at"),
        "updatedAt": d.get("updated_at"),
    }


# ========== 个人提交 ==========

class PersonKycReq(BaseModel):
    name: str
    idcard: str
    phone: str
    sms: Optional[str] = ""
    id_front_url: Optional[str] = ""
    id_back_url: Optional[str] = ""
    face_url: Optional[str] = ""
    agree: Optional[bool] = True


@router.post("/submit/person")
def submit_person(req: PersonKycReq, user=Depends(require_permission("kyc:submit")), request: Request = None):
    name = (req.name or "").strip()
    idcard = (req.idcard or "").strip().upper()
    phone = (req.phone or "").strip()
    if not req.agree: return fail("请先阅读并同意《实名认证用户协议》")
    if len(name) < 2: return fail("请输入真实姓名（至少2字）")
    if not _idcard_valid(idcard): return fail("身份证号格式不正确（18位，末位可为X）")
    if not re.fullmatch(r"1[3-9]\d{9}", phone): return fail("手机号格式不正确")
    if req.sms and (req.sms.strip() != "123456"):
        pass

    with get_conn() as conn:
        # 若已有 pending / passed 记录则不允许重复提交
        recent = conn.execute(
            "SELECT id,status FROM kyc_verifications WHERE user_id=? AND status IN ('pending','passed') ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()
        if recent:
            if recent["status"] == "pending": return fail("您的认证资料已提交，正在审核中，请耐心等待")
            if recent["status"] == "passed": return fail("您已完成实名认证，无需重复提交")

        cur = conn.execute(
            """INSERT INTO kyc_verifications
                 (user_id,type,status,name,idcard,phone,id_front_url,id_back_url,face_url)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (user["id"], "person", "pending", name, idcard, phone,
             req.id_front_url or "", req.id_back_url or "", req.face_url or ""),
        )
        kid = cur.lastrowid

    audit_kyc_submit(
        user,
        resource_type="kyc",
        resource_id=str(kid),
        new={"type": "person", "idcard": _mask(idcard, 3, 4), "phone": _mask(phone, 3, 4), "name_len": len(name)},
        summary=f"提交个人实名认证 #{kid}：姓名（{len(name)}字）+ 手机号 {_mask(phone,3,4)}",
        ip=request.client.host if request and request.client else None,
        ua=request.headers.get("user-agent") if request else None,
    )
    return ok({"id": kid, "status": "pending"}, "个人认证资料已提交，等待审核（通常3秒-1个工作日）")


# ========== 企业提交 ==========

class CompanyKycReq(BaseModel):
    company: str
    uscc: str
    legal_name: str
    legal_idcard: str
    bank_account: Optional[str] = ""
    contact_email: Optional[str] = ""
    license_url: Optional[str] = ""
    agree: Optional[bool] = True


@router.post("/submit/company")
def submit_company(req: CompanyKycReq, user=Depends(require_permission("kyc:submit")), request: Request = None):
    company = (req.company or "").strip()
    uscc = (req.uscc or "").strip().upper()
    legal_name = (req.legal_name or "").strip()
    legal_idcard = (req.legal_idcard or "").strip().upper()
    if not req.agree: return fail("请先阅读并同意《实名认证用户协议》")
    if len(company) < 4: return fail("请输入完整的企业名称")
    if not _uscc_valid(uscc): return fail("统一社会信用代码格式不正确（18位大写字母/数字）")
    if len(legal_name) < 2: return fail("请输入法人姓名")
    if not _idcard_valid(legal_idcard): return fail("法人身份证号格式不正确")
    if req.contact_email and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", req.contact_email.strip()):
        return fail("联系人邮箱格式不正确")

    with get_conn() as conn:
        recent = conn.execute(
            "SELECT id,status FROM kyc_verifications WHERE user_id=? AND status IN ('pending','passed') ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()
        if recent:
            if recent["status"] == "pending": return fail("您的认证资料已提交，正在审核中，请耐心等待")
            if recent["status"] == "passed": return fail("您已完成实名认证，无需重复提交")

        cur = conn.execute(
            """INSERT INTO kyc_verifications
                 (user_id,type,status,company,uscc,legal_name,legal_idcard,bank_account,contact_email,license_url)
               VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (user["id"], "company", "pending", company, uscc, legal_name, legal_idcard,
             req.bank_account or "", req.contact_email or "", req.license_url or ""),
        )
        kid = cur.lastrowid

    audit_kyc_submit(
        user,
        resource_type="kyc",
        resource_id=str(kid),
        new={"type": "company",
             "company_len": len(company),
             "uscc": _mask(uscc, 4, 4),
             "legal_name_len": len(legal_name),
             "legal_idcard": _mask(legal_idcard, 3, 4),
             "contact_email": req.contact_email or ""},
        summary=f"提交企业实名认证 #{kid}：企业名称（{len(company)}字）+ 统一代码 {_mask(uscc,4,4)}",
        ip=request.client.host if request and request.client else None,
        ua=request.headers.get("user-agent") if request else None,
    )
    return ok({"id": kid, "status": "pending"}, "企业认证资料已提交，等待审核")


# ========== 用户端：查询我的最新认证状态 ==========

@router.get("/my-status")
def my_status(user=Depends(require_permission("kyc:view"))):
    """返回当前用户最新一条 KYC 记录（脱敏）"""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM kyc_verifications WHERE user_id=? ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()
    if not row:
        return ok({"status": "none", "record": None}, "尚未提交实名认证")
    d = dict(row)
    return ok({"status": d["status"], "record": _mask_row_to_public(d)})


# ========== 管理端：列表 + 审核通过/驳回 ==========

@router.get("/admin/list")
def admin_list(
    page: int = 1, pageSize: int = 20,
    status: Optional[str] = None, q_type: Optional[str] = None, keyword: Optional[str] = None,
    user=Depends(require_permission("kyc:audit")),
):
    where, params = [], []
    if status and status != "all": where.append("status=?"); params.append(status)
    if q_type and q_type != "all": where.append("type=?"); params.append(q_type)
    if keyword:
        where.append("(name LIKE ? OR company LIKE ? OR idcard LIKE ? OR user_id IN (SELECT id FROM users WHERE username LIKE ?))")
        k = f"%{keyword.strip()}%"; params += [k, k, k, k]
    wc = ("WHERE " + " AND ".join(where)) if where else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM kyc_verifications {wc}", params).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM kyc_verifications {wc} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    items = []
    for r in rows:
        d = dict(r)
        # 管理员可看原始数据（不解密，仅页面显示时前端自己做脱敏）
        d["idcard"] = _mask(d.get("idcard") or "", 3, 4)
        d["phone"] = _mask(d.get("phone") or "", 3, 4)
        d["legal_idcard"] = _mask(d.get("legal_idcard") or "", 3, 4)
        items.append(d)
    return ok({"total": total, "page": page, "pageSize": pageSize, "list": items})


class AuditReq(BaseModel):
    id: int
    pass_: bool = True
    reason: Optional[str] = ""


@router.post("/admin/audit")
def admin_audit(req: AuditReq, user=Depends(require_permission("kyc:audit")), request: Request = None):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM kyc_verifications WHERE id=?", (req.id,)).fetchone()
        if not row: return fail("记录不存在", 404)
        if row["status"] != "pending": return fail(f"当前状态为 {row['status']}，无法审核")
        old_status = row["status"]
        new_status = "passed" if req.pass_ else "rejected"
        reject_reason = "" if req.pass_ else (req.reason or "资料不符合要求")
        conn.execute(
            """UPDATE kyc_verifications SET
                 status=?, reject_reason=?, reviewed_by=?, reviewed_at=datetime('now','localtime'),
                 updated_at=datetime('now','localtime')
               WHERE id=?""",
            (new_status, reject_reason, user["id"], req.id),
        )
    audit_kyc_audit(
        user,
        resource_type="kyc",
        resource_id=str(req.id),
        old={"status": old_status, "type": row.get("type"), "user_id": row.get("user_id")},
        new={"status": new_status, "reject_reason": (reject_reason[:60] if reject_reason else None)},
        summary=f"管理员审核 KYC#{req.id}（{row.get('type') or '?'}）：{old_status} → {new_status}"
                + (f"，原因：{reject_reason[:40]}" if new_status == "rejected" else ""),
        ip=request.client.host if request and request.client else None,
        ua=request.headers.get("user-agent") if request else None,
    )
    return ok(None, f"已{'通过' if req.pass_ else '驳回'}该实名认证")


# ========== 模拟自动审核（演示环境用）：触发后 3 秒自动通过最近一条 pending ==========

@router.post("/demo/auto-pass")
def demo_auto_pass(user=Depends(get_current_user)):
    """演示专用：把当前用户最近一条 pending 置为 passed（无权限要求登录即可）"""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id FROM kyc_verifications WHERE user_id=? AND status='pending' ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()
        if not row: return fail("没有待审核的记录")
        conn.execute(
            "UPDATE kyc_verifications SET status='passed', reviewed_by=?, reviewed_at=datetime('now','localtime'), updated_at=datetime('now','localtime') WHERE id=?",
            (user["id"], row["id"]),
        )
    return ok(None, "演示：已自动通过审核，刷新查看")
