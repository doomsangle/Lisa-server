import ipaddress
import json
import socket
import time
import urllib.parse
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional, List, Tuple, Any
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from core.database import get_conn
from core.security import get_current_user, require_permission

router = APIRouter(prefix="/check", tags=["检测中心"])


def ok(data=None, message="ok"):
    return {"code": 0, "message": message, "data": data}


def fail(message, code=400):
    return {"code": code, "message": message, "data": None}


# ========== 常用 RBL 黑名单列表（真实 DNSBL，全球10大主流） ==========
RBL_PROVIDERS = [
    "zen.spamhaus.org",
    "bl.spamcop.net",
    "dnsbl.sorbs.net",
    "cbl.abuseat.org",
    "dnsbl-1.uceprotect.net",
    "dnsbl-2.uceprotect.net",
    "dnsbl-3.uceprotect.net",
    "ix.dnsbl.manitu.net",
    "b.barracudacentral.org",
    "psbl.surriel.com",
    "combined.abuse.ch",
    "db.wpbl.info",
    "spam.dnsbl.sorbs.net",
    "sbl.spamhaus.org",
    "xbl.spamhaus.org",
    "pbl.spamhaus.org",
    "all.s5h.net",
    "rbl.efnetrbl.org",
    "http.dnsbl.sorbs.net",
    "misc.dnsbl.sorbs.net",
    "smtp.dnsbl.sorbs.net",
    "socks.dnsbl.sorbs.net",
    "web.dnsbl.sorbs.net",
    "zombie.dnsbl.sorbs.net",
    "dul.dnsbl.sorbs.net",
    "dyna.spamrats.com",
    "noptr.spamrats.com",
    "spam.spamrats.com",
    "auth.spamrats.com",
    "list.dnswl.org",
    "dnsbl.inps.de",
    "bl.blocklist.de",
    "rbl.abuse.ro",
    "spamlist.or.kr",
    "dbl.abuse.ch",
    "dnsbl.justspam.org",
    "hostkarma.junkemailfilter.com",
    "u1.misuse.ca",
    "v4.fullbogons.cymru.com",
    "tor.ahbl.org",
    "torexit.dan.me.uk",
    "exitnodes.tor.dnsbl.sectoor.de",
    "rbl.0spam.org",
    "singular.ttk.pte.hu",
    "spam.abuse.ch",
    "wormrbl.imp.ch",
    "virbl.bit.nl",
    "short.rbl.jp",
]


def _http_get_json(url, timeout=8, headers=None):
    """urllib 实现的 HTTP GET，返回 (status_code, parsed_json_or_None, error_msg)"""
    try:
        req = urllib.request.Request(url, headers=headers or {
            "User-Agent": "MetoE-IP-Checker/1.0 (+https://metoe.io)",
            "Accept": "application/json",
        })
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="ignore")
            try:
                return resp.status, json.loads(body), None
            except Exception as e:
                return resp.status, None, f"json parse error: {str(e)[:60]}"
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode("utf-8", errors="ignore")[:200]
        except Exception:
            body = ""
        return e.code, None, f"HTTP {e.code}: {body[:120]}"
    except Exception as e:
        return 0, None, str(e)[:120]


def _load_config_key(conn, key_name):
    """从 system_configs 表读取配置；未配置返回 None"""
    try:
        row = conn.execute("SELECT value FROM system_configs WHERE key = ?", (key_name,)).fetchone()
        v = (row or {}).get("value") or ""
        return v if v and not v.startswith("DEMO-") and not v.startswith("模拟") and not v.startswith("sk_lisa_demo") else None
    except Exception:
        return None


def is_valid_ipv4(ip: str) -> bool:
    try:
        ipaddress.IPv4Address(ip)
        return True
    except Exception:
        return False


def is_valid_ip(ip: str) -> bool:
    try:
        ipaddress.ip_address(ip)
        return True
    except Exception:
        return False


# ========== 单项真实检测函数 ==========

def detect_geo_asn(ip: str):
    """
    真实 Geo 地理定位 + ASN 归属
    使用 ip-api.com 免费公开 API（每分钟45次，无需 Key）
    备用：ipwho.is（免费）
    """
    for api_url in [
        f"http://ip-api.com/json/{urllib.parse.quote(ip)}?fields=status,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,mobile,proxy,hosting,query",
        f"https://ipwho.is/{urllib.parse.quote(ip)}?lang=en",
    ]:
        status, j, err = _http_get_json(api_url, timeout=3)
        if status == 200 and j:
            success = j.get("success") if api_url.startswith("https://ipwho.is") else (j.get("status") == "success")
            if success:
                cc = j.get("country_code") or j.get("countryCode") or ""
                country = j.get("country") or ""
                region = j.get("region") or j.get("region_name") or j.get("regionName") or ""
                city = j.get("city") or ""
                isp = j.get("isp") or j.get("connection", {}).get("isp") or ""
                org = j.get("org") or ""
                as_raw = j.get("as") or j.get("connection", {}).get("asn") or ""
                as_name = j.get("asname") or j.get("connection", {}).get("org") or ""
                flag_map = {
                    "US": "🇺🇸", "CN": "🇨🇳", "JP": "🇯🇵", "KR": "🇰🇷", "SG": "🇸🇬",
                    "GB": "🇬🇧", "DE": "🇩🇪", "FR": "🇫🇷", "NL": "🇳🇱", "CA": "🇨🇦",
                    "AU": "🇦🇺", "BR": "🇧🇷", "IN": "🇮🇳", "RU": "🇷🇺", "HK": "🇭🇰",
                    "TW": "🇹🇼", "VN": "🇻🇳", "ID": "🇮🇩", "MY": "🇲🇾", "TH": "🇹🇭",
                    "PH": "🇵🇭", "MX": "🇲🇽", "ES": "🇪🇸", "IT": "🇮🇹", "PL": "🇵🇱",
                    "SE": "🇸🇪", "CH": "🇨🇭", "BE": "🇧🇪", "NO": "🇳🇴", "DK": "🇩🇰",
                    "FI": "🇫🇮", "IE": "🇮🇪", "PT": "🇵🇹", "GR": "🇬🇷", "CZ": "🇨🇿",
                    "AT": "🇦🇹", "NZ": "🇳🇿", "ZA": "🇿🇦", "TR": "🇹🇷", "AE": "🇦🇪",
                    "SA": "🇸🇦", "IL": "🇮🇱", "UA": "🇺🇦", "AR": "🇦🇷", "CL": "🇨🇱",
                    "CO": "🇨🇴", "PE": "🇵🇪", "PK": "🇵🇰", "BD": "🇧🇩", "EG": "🇪🇬",
                    "NG": "🇳🇬", "KE": "🇰🇪", "UZ": "🇺🇿", "KZ": "🇰🇿",
                }
                flag = flag_map.get(cc, "🌐")
                geo_text = f"{flag} {country}" + (f" · {region}" if region else "") + (f" · {city}" if city else "")
                asn_text = str(as_raw) + (f" {as_name}" if as_name and as_name not in str(as_raw) else "") + (f" · ISP: {isp}" if isp else "")
                extra_flags = []
                if j.get("mobile"): extra_flags.append("移动")
                if j.get("proxy"): extra_flags.append("代理")
                if j.get("hosting"): extra_flags.append("IDC")
                if extra_flags:
                    asn_text += f" [{','.join(extra_flags)}]"
                return True, {
                    "country": f"{flag} {country}" if country else (flag + " 未知"),
                    "countryCode": cc,
                    "geo": geo_text,
                    "asn": asn_text,
                    "raw": {"flag": flag, "country": country, "cc": cc, "region": region, "city": city, "isp": isp, "org": org, "as": str(as_raw), "as_name": as_name},
                }
    return False, {
        "country": "🌐 未知",
        "countryCode": "",
        "geo": "🌐 Geo API 暂不可用（请检查网络）",
        "asn": "ASN 检测失败",
    }


def _check_single_rbl(reversed_ip: str, rbl: str) -> Optional[str]:
    query = f"{reversed_ip}.{rbl}"
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(1.0)
        answers = socket.gethostbyname_ex(query)[2]
        if any(a.startswith("127.") for a in answers):
            return rbl
    except Exception:
        pass
    return None


def detect_rbl(ip: str, providers=None, max_workers=24):
    if not is_valid_ipv4(ip):
        return 0, len(RBL_PROVIDERS), "IPv6 跳过（多数RBL不支持IPv6）"
    parts = ip.split(".")
    reversed_ip = ".".join(reversed(parts))
    providers = providers or RBL_PROVIDERS
    total = len(providers)
    details = []
    pool = None
    try:
        pool = ThreadPoolExecutor(max_workers=max_workers)
        futures = {pool.submit(_check_single_rbl, reversed_ip, rbl): rbl for rbl in providers}
        try:
            for fut in as_completed(futures, timeout=2.5):
                try:
                    res = fut.result()
                    if res:
                        details.append(res)
                except Exception:
                    pass
        except Exception:
            pass
    except Exception:
        pass
    finally:
        if pool:
            try:
                pool.shutdown(wait=False, cancel_futures=True)
            except Exception:
                pool.shutdown(wait=False)
    hit = len(details)
    detail_str = f"命中: {', '.join(details[:8])}" if details else "未命中"
    return hit, total, detail_str


def detect_abuseipdb(ip: str, api_key: Optional[str]):
    """
    真实 AbuseIPDB 检测（行业金标准）
    需要 API Key：官网 https://www.abuseipdb.com 免费注册，每天1000次
    未配置 Key：明确告知用户"未配置API Key，跳过该检测"
    """
    if not api_key:
        return False, "未配置 AbuseIPDB API Key，跳过检测（在系统配置中设置 abuseipdb_api_key）"
    url = f"https://api.abuseipdb.com/api/v2/check?ipAddress={urllib.parse.quote(ip)}&maxAgeInDays=90&verbose"
    status, j, err = _http_get_json(url, timeout=8, headers={
        "Key": api_key,
        "Accept": "application/json",
        "User-Agent": "MetoE-IP-Checker/1.0",
    })
    if status == 200 and j and "data" in j:
        d = j["data"]
        score = d.get("abuseConfidenceScore", 0)
        total_reports = d.get("totalReports", 0)
        last_report = d.get("lastReportedAt", "")
        categories = d.get("categories", [])
        usage_type = d.get("usageType", "")
        isp = d.get("isp", "")
        is_tor = d.get("isTor", False)
        is_web = d.get("isWeb", False)
        text = f"置信度 {score}/100 · 报告 {total_reports} 次"
        if last_report: text += f" · 最近: {str(last_report)[:10]}"
        if usage_type: text += f" · 用途: {usage_type}"
        if isp: text += f" · ISP: {isp}"
        if categories: text += f"\n举报类别: {', '.join(map(str, categories[:8]))}"
        tags = []
        if is_tor: tags.append("TOR")
        if is_web: tags.append("Web服务")
        if tags: text += f" [{','.join(tags)}]"
        return True, {
            "text": text,
            "confidence": int(score),
            "totalReports": int(total_reports),
            "categories": categories,
            "isTor": bool(is_tor),
            "usageType": usage_type,
        }
    return False, f"AbuseIPDB 检测失败: {err or f'HTTP {status}'}"


def detect_ipqualityscore(ip: str, api_key: Optional[str]):
    """
    真实 IPQualityScore 欺诈检测
    需要 API Key：https://www.ipqualityscore.com 免费额度
    """
    if not api_key:
        return False, "未配置 IPQualityScore API Key，跳过检测（系统配置 ipqs_api_key）"
    url = f"https://ipqualityscore.com/api/json/ip/{urllib.parse.quote(api_key)}/{urllib.parse.quote(ip)}?strictness=1&allow_public_access_points=true&fast=true"
    status, j, err = _http_get_json(url, timeout=8)
    if status == 200 and j and j.get("success"):
        fraud = j.get("fraud_score", 0)
        is_vpn = j.get("vpn", False)
        is_proxy = j.get("proxy", False)
        is_tor = j.get("tor", False)
        is_bot = j.get("bot_status", False)
        is_crawler = j.get("is_crawler", False)
        is_datacenter = j.get("recent_abuse", False) or j.get("active_vpn", False)
        asn_name = j.get("ASN", "") or j.get("isp", "")
        org = j.get("ISP", "")
        city = j.get("city", "")
        region = j.get("region", "")
        text = (f"欺诈分 {fraud}/100，"
                f"数据中心={'是' if is_datacenter else '否'}，"
                f"住宅={'否' if (is_vpn or is_proxy or is_datacenter) else '是'}，"
                f"移动={'是' if j.get('mobile') else '否'}")
        tags = []
        if is_vpn: tags.append("VPN")
        if is_proxy: tags.append("代理")
        if is_tor: tags.append("TOR")
        if is_bot: tags.append("BOT")
        if is_crawler: tags.append("爬虫")
        if tags: text += f" [{','.join(tags)}]"
        if asn_name: text += f" · {asn_name}"
        return True, {
            "text": text,
            "fraudScore": int(fraud),
            "vpn": bool(is_vpn),
            "proxy": bool(is_proxy),
            "tor": bool(is_tor),
            "bot": bool(is_bot),
            "crawler": bool(is_crawler),
            "datacenter": bool(is_datacenter),
            "mobile": bool(j.get("mobile", False)),
        }
    return False, f"IPQualityScore 检测失败: {err or f'HTTP {status}'}"


def detect_scamalytics(ip: str, api_key: Optional[str], username: Optional[str] = None):
    """
    真实 Scamalytics 评分检测
    需要 API Key / Username：https://scamalytics.com/api
    """
    if not api_key or not username:
        return False, "未配置 Scamalytics Username/API Key，跳过检测（系统配置 scamalytics_user + scamalytics_api_key）"
    url = f"https://api11.scamalytics.com/{urllib.parse.quote(username)}/?key={urllib.parse.quote(api_key)}&ip={urllib.parse.quote(ip)}"
    status, j, err = _http_get_json(url, timeout=8)
    if status == 200 and j:
        score = j.get("score", j.get("risk_score", 0))
        risk = j.get("risk", "")
        isp_name = j.get("isp_name", "")
        url_all = j.get("url_all", "")
        url_fraud = j.get("url_fraud", "")
        device = j.get("device", "")
        anon = j.get("anonymizer", "")
        text = f"风险评分 {score}/100"
        if risk: text += f"，风险等级={risk}"
        if isp_name: text += f"，ISP={isp_name}"
        if anon: text += f" [{anon}]"
        if url_all: text += f"\n全网记录: {url_all}"
        if url_fraud and int(url_fraud or 0) > 0: text += f"，欺诈记录: {url_fraud}"
        return True, {"text": text, "score": int(score), "risk": risk, "isp": isp_name}
    return False, f"Scamalytics 检测失败: {err or f'HTTP {status}'}"


def detect_spur(ip: str, api_key: Optional[str]):
    """
    真实 Spur.us VPN/Residential 检测（精准识别住宅 / 机房 / VPN）
    需要 API Key：https://spur.us/api
    """
    if not api_key:
        return False, "未配置 Spur.us API Key，跳过检测（系统配置 spur_api_key）"
    url = f"https://spur.us/api/v2/context/{urllib.parse.quote(ip)}"
    status, j, err = _http_get_json(url, timeout=8, headers={"Token": api_key})
    if status == 200 and j:
        client_types = j.get("clientTypes", []) or []
        infrastructure = j.get("infrastructure", "") or j.get("org", "")
        asn_info = j.get("as", {}) or {}
        tag_states = j.get("tags", []) or []
        services = j.get("services", []) or []
        is_vpn = "VPN" in str(client_types) or any("vpn" in str(x).lower() for x in client_types + tag_states + services)
        is_proxy = "PROXY" in str(client_types) or any("proxy" in str(x).lower() for x in client_types + tag_states + services)
        is_residential = (
            j.get("location", {}).get("type") == "residential"
            or any("residential" in str(x).lower() for x in client_types + tag_states)
            or (not is_vpn and not is_proxy and not any("datacenter" in str(infrastructure).lower()))
        )
        text_parts = []
        if is_vpn: text_parts.append("VPN 出口")
        if is_proxy: text_parts.append("代理出口")
        if is_residential: text_parts.append("住宅IP")
        if infrastructure: text_parts.append(f"基础设施={infrastructure}")
        if asn_info: text_parts.append(f"AS={asn_info}")
        if tag_states: text_parts.append(f"状态标签={','.join(tag_states[:5])}")
        text = ("NO VPN/Proxy detected，Residential: true" if (not text_parts and is_residential)
                else "；".join(text_parts) if text_parts else f"Spur 检测通过")
        return True, {
            "text": text,
            "clientTypes": client_types,
            "infrastructure": infrastructure,
            "vpn": bool(is_vpn),
            "proxy": bool(is_proxy),
            "residential": bool(is_residential),
            "tags": tag_states,
        }
    return False, f"Spur.us 检测失败: {err or f'HTTP {status}'}"


# ========== 综合评分算法 ==========

def compute_composite_score(
    geo_asn_ok, geo_asn_result,
    rbl_hit, rbl_total,
    abuse_ok, abuse_result,
    ipqs_ok, ipqs_result,
    scam_ok, scam_result,
    spur_ok, spur_result,
):
    """
    行业标准加权评分（满分100，越高越好）
    判定：>= 80 PASS  |  50-79 WARNING  |  < 50 FAIL
    """
    score = 100
    reasons = []

    # --- RBL 扣分：每条命中扣 10 分，最多扣 40 ---
    if rbl_hit >= 1:
        rbl_deduct = min(40, rbl_hit * 10)
        score -= rbl_deduct
        reasons.append(f"RBL命中 {rbl_hit} 条黑名单 扣 {rbl_deduct}")

    # --- AbuseIPDB 扣分 ---
    if abuse_ok and isinstance(abuse_result, dict):
        conf = int(abuse_result.get("confidence", 0) or 0)
        reports = int(abuse_result.get("totalReports", 0) or 0)
        is_tor = bool(abuse_result.get("isTor"))
        if conf >= 80:
            score -= 30; reasons.append(f"Abuse置信度{conf}≥80 扣30")
        elif conf >= 50:
            score -= 12; reasons.append(f"Abuse置信度{conf}≥50 扣12")
        elif conf >= 20:
            score -= 5; reasons.append(f"Abuse置信度{conf}≥20 扣5")
        if reports >= 50:
            score -= 12; reasons.append(f"Abuse报告{reports}≥50 扣12")
        elif reports >= 10:
            score -= 5; reasons.append(f"Abuse报告{reports}≥10 扣5")
        if is_tor:
            score -= 15; reasons.append("TOR节点 扣15")

    # --- IPQualityScore 扣分 ---
    if ipqs_ok and isinstance(ipqs_result, dict):
        fraud = int(ipqs_result.get("fraudScore", 0) or 0)
        if fraud >= 80:
            score -= 28; reasons.append(f"IPQS欺诈分{fraud}≥80 扣28")
        elif fraud >= 50:
            score -= 12; reasons.append(f"IPQS欺诈分{fraud}≥50 扣12")
        elif fraud >= 25:
            score -= 5; reasons.append(f"IPQS欺诈分{fraud}≥25 扣5")
        if bool(ipqs_result.get("vpn")): score -= 10; reasons.append("IPQS标记VPN 扣10")
        if bool(ipqs_result.get("proxy")): score -= 10; reasons.append("IPQS标记代理 扣10")
        if bool(ipqs_result.get("tor")): score -= 15; reasons.append("IPQS标记TOR 扣15")
        if bool(ipqs_result.get("bot")): score -= 8; reasons.append("IPQS标记BOT 扣8")

    # --- Scamalytics 扣分 ---
    if scam_ok and isinstance(scam_result, dict):
        sc = int(scam_result.get("score", 0) or 0)
        if sc >= 80:
            score -= 20; reasons.append(f"Scamalytics风险{sc}≥80 扣20")
        elif sc >= 50:
            score -= 10; reasons.append(f"Scamalytics风险{sc}≥50 扣10")
        elif sc >= 30:
            score -= 4; reasons.append(f"Scamalytics风险{sc}≥30 扣4")

    # --- Spur.us 扣分 ---
    if spur_ok and isinstance(spur_result, dict):
        if bool(spur_result.get("vpn")): score -= 12; reasons.append("Spur标记VPN 扣12")
        if bool(spur_result.get("proxy")): score -= 12; reasons.append("Spur标记代理 扣12")

    # --- Geo/ASN 识别失败不扣分，但标记 ---
    if not geo_asn_ok:
        reasons.append("Geo定位失败（不扣分，需重试）")

    score = max(0, min(100, int(score)))
    if score >= 80:
        conclusion = "PASS"
    elif score >= 50:
        conclusion = "WARNING"
    else:
        conclusion = "FAIL"
    return score, conclusion, "；".join(reasons) if reasons else "无扣分项，网络状态良好"


# ========== FastAPI 路由 ==========

class CheckIpReq(BaseModel):
    ip: str
    checks: List[str] = ["geo", "asn", "rbl", "abuse", "ipqs", "scam", "spur"]


@router.post("/ip")
def check_ip(req: CheckIpReq, user=Depends(require_permission("check:run"))):
    """
    真实 IP 健康检测（返回真实结果 + 保存到 DB）
    检测流程完全基于真实公开 API / DNS 查询，非随机数据。
    """
    ip = (req.ip or "").strip()
    if not ip:
        return fail("请输入 IP")
    if not is_valid_ip(ip):
        return fail(f"IP 格式不正确：{ip}")

    selected = set(req.checks or [])
    t0 = time.time()

    # --- Step 1: Geo + ASN + RBL 并行执行 ---
    geo_asn_ok, geo_asn_result = False, {
        "country": "🌐 未知", "countryCode": "", "geo": "检测超时", "asn": "检测超时"
    }
    rbl_hit, rbl_total, rbl_detail = 0, 48, "未启用"
    step1_tasks: List[Tuple[str, Any]] = []
    if "geo" in selected or "asn" in selected:
        step1_tasks.append(("geo", lambda: detect_geo_asn(ip)))
    if "rbl" in selected:
        step1_tasks.append(("rbl", lambda: detect_rbl(ip)))

    if step1_tasks:
        pool1 = None
        try:
            pool1 = ThreadPoolExecutor(max_workers=min(4, len(step1_tasks)))
            fut_map = {pool1.submit(fn): name for name, fn in step1_tasks}
            try:
                for fut in as_completed(fut_map, timeout=4):
                    name = fut_map[fut]
                    try:
                        res = fut.result()
                        if name == "geo":
                            geo_asn_ok, geo_asn_result = res
                        elif name == "rbl":
                            rbl_hit, rbl_total, rbl_detail = res
                    except Exception:
                        pass
            except Exception:
                pass
        finally:
            if pool1:
                try:
                    pool1.shutdown(wait=False, cancel_futures=True)
                except Exception:
                    pool1.shutdown(wait=False)

    # --- Step 3: 信誉类 API（需要 Key，优雅降级，并行执行） ---
    with get_conn() as conn:
        abuseipdb_key = _load_config_key(conn, "abuseipdb_api_key")
        ipqs_key = _load_config_key(conn, "ipqs_api_key")
        scam_user = _load_config_key(conn, "scamalytics_user")
        scam_key = _load_config_key(conn, "scamalytics_api_key")
        spur_key = _load_config_key(conn, "spur_api_key")

    tasks: List[Tuple[str, Any]] = []
    if "abuse" in selected:
        tasks.append(("abuse", lambda k=abuseipdb_key: detect_abuseipdb(ip, k)))
    if "ipqs" in selected:
        tasks.append(("ipqs", lambda k=ipqs_key: detect_ipqualityscore(ip, k)))
    if "scam" in selected:
        tasks.append(("scam", lambda k=scam_key, u=scam_user: detect_scamalytics(ip, k, u)))
    if "spur" in selected:
        tasks.append(("spur", lambda k=spur_key: detect_spur(ip, k)))

    results: dict = {}
    if tasks:
        pool3 = None
        try:
            pool3 = ThreadPoolExecutor(max_workers=min(4, len(tasks)))
            fut_map = {pool3.submit(fn): name for name, fn in tasks}
            try:
                for fut in as_completed(fut_map, timeout=4):
                    name = fut_map[fut]
                    try:
                        _ok, _res = fut.result()
                        results[name] = (_ok, _res)
                    except Exception as e:
                        results[name] = (False, f"执行异常: {str(e)[:80]}")
            except Exception:
                pass
        finally:
            if pool3:
                try:
                    pool3.shutdown(wait=False, cancel_futures=True)
                except Exception:
                    pool3.shutdown(wait=False)

    abuse_ok, abuse_result = results.get("abuse", (False, "未启用"))
    ipqs_ok, ipqs_result = results.get("ipqs", (False, "未启用"))
    scam_ok, scam_result = results.get("scam", (False, "未启用"))
    spur_ok, spur_result = results.get("spur", (False, "未启用"))

    # --- Step 4: 综合评分 ---
    score, conclusion, reasons_str = compute_composite_score(
        geo_asn_ok, geo_asn_result,
        rbl_hit, rbl_total,
        abuse_ok, abuse_result,
        ipqs_ok, ipqs_result,
        scam_ok, scam_result,
        spur_ok, spur_result,
    )

    country = geo_asn_result.get("country", "🌐 未知") if isinstance(geo_asn_result, dict) else "🌐 未知"
    country_code = geo_asn_result.get("countryCode", "") if isinstance(geo_asn_result, dict) else ""
    geo_text = geo_asn_result.get("geo", "") if isinstance(geo_asn_result, dict) else str(geo_asn_result)[:200]
    asn_text = geo_asn_result.get("asn", "") if isinstance(geo_asn_result, dict) else ""
    abuse_text = abuse_result.get("text", "") if (abuse_ok and isinstance(abuse_result, dict)) else (str(abuse_result)[:200] if isinstance(abuse_result, str) else "")
    ipqs_text = ipqs_result.get("text", "") if (ipqs_ok and isinstance(ipqs_result, dict)) else (str(ipqs_result)[:200] if isinstance(ipqs_result, str) else "")
    scam_text = scam_result.get("text", "") if (scam_ok and isinstance(scam_result, dict)) else (str(scam_result)[:200] if isinstance(scam_result, str) else "")
    spur_text = spur_result.get("text", "") if (spur_ok and isinstance(spur_result, dict)) else (str(spur_result)[:200] if isinstance(spur_result, str) else "")

    # --- Step 5: 保存到 SQLite 数据库 check_records 表 ---
    record_id = None
    try:
        with get_conn() as conn:
            cur = conn.execute(
                """INSERT INTO check_records
                     (user_id, ip, country, score, conclusion, geo, asn, rbl_hit, rbl_total, abuse, ipqs, scamalytic, spur)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    user["id"], ip, country, score, conclusion,
                    geo_text, asn_text, int(rbl_hit), int(rbl_total),
                    abuse_text, ipqs_text, scam_text, spur_text,
                ),
            )
            record_id = cur.lastrowid
    except Exception as save_err:
        # 即便保存失败也要把真实检测结果返回给用户
        reasons_str += f" [警告：DB保存失败 {str(save_err)[:60]}]"

    elapsed = round(time.time() - t0, 2)
    record = {
        "id": record_id,
        "ip": ip,
        "country": country,
        "countryCode": country_code,
        "score": score,
        "conclusion": conclusion,
        "reasons": reasons_str,
        "geo": geo_text,
        "asn": asn_text,
        "rblHit": int(rbl_hit),
        "rblTotal": int(rbl_total),
        "rblDetail": rbl_detail,
        "abuse": abuse_text,
        "ipqs": ipqs_text,
        "scamalytic": scam_text,
        "spur": spur_text,
        "elapsedSec": elapsed,
        "checksEnabled": list(selected),
        "skips": {
            "abuse": None if abuse_ok else (abuse_result if isinstance(abuse_result, str) else "未执行"),
            "ipqs": None if ipqs_ok else (ipqs_result if isinstance(ipqs_result, str) else "未执行"),
            "scamalytics": None if scam_ok else (scam_result if isinstance(scam_result, str) else "未执行"),
            "spur": None if spur_ok else (spur_result if isinstance(spur_result, str) else "未执行"),
        },
    }
    return ok(record, f"真实检测完成（{elapsed}s）：{conclusion}（{score}分）")


@router.get("/history")
def history(
    page: int = 1, pageSize: int = 20,
    user=Depends(require_permission("check:history")),
):
    """真实历史记录：从 SQLite check_records 表分页读取"""
    uid_clause = "" if user["is_super_admin"] else "WHERE user_id = ?"
    params = [] if user["is_super_admin"] else [user["id"]]
    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) c FROM check_records {uid_clause}", params
        ).fetchone()["c"]
        rows = conn.execute(
            f"SELECT * FROM check_records {uid_clause} ORDER BY id DESC LIMIT ? OFFSET ?",
            params + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    list_data = []
    for r in rows:
        d = dict(r)
        abuse_val = d.get("abuse") or ""
        try:
            if isinstance(abuse_val, str) and "置信度" in abuse_val and "/100" in abuse_val:
                part = abuse_val.split("置信度 ", 1)[1].split("/100", 1)[0]
                abuse_short = f"置信度 {part}/100"
            else:
                abuse_short = abuse_val[:30] if abuse_val else "-"
        except Exception:
            abuse_short = abuse_val[:30] if abuse_val else "-"
        list_data.append({
            "id": d.get("id"),
            "ts": d.get("created_at", ""),
            "ip": d.get("ip", ""),
            "country": d.get("country", "") or "🌐 未知",
            "rbl": int(d.get("rbl_hit") or 0),
            "abuse": abuse_short,
            "score": int(d.get("score") or 0),
        })
    return ok({"total": total, "page": page, "pageSize": pageSize, "list": list_data})


@router.get("/record/{record_id}")
def record_detail(record_id: int, user=Depends(require_permission("check:history"))):
    """单条检测详情：用于「查看」按钮弹窗"""
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM check_records WHERE id = ?", (record_id,)).fetchone()
        if not row:
            return fail("记录不存在", 404)
        d = dict(row)
        if not user["is_super_admin"] and d.get("user_id") != user["id"]:
            return fail("无权查看该记录", 403)
        return ok(d)


@router.get("/export")
def export_csv(user=Depends(require_permission("check:history"))):
    """导出 CSV"""
    from fastapi.responses import PlainTextResponse
    uid_clause = "" if user["is_super_admin"] else "WHERE user_id = ?"
    params = [] if user["is_super_admin"] else [user["id"]]
    with get_conn() as conn:
        rows = conn.execute(
            f"SELECT id, created_at, ip, country, score, conclusion, rbl_hit, abuse FROM check_records {uid_clause} ORDER BY id DESC LIMIT 500",
            params,
        ).fetchall()
    headers = ["ID", "时间", "IP", "地区", "分数", "结论", "RBL命中", "AbuseIPDB"]
    lines = [",".join(headers)]
    for r in rows:
        cols = [
            str(r["id"]),
            str(r["created_at"] or ""),
            str(r["ip"] or ""),
            (str(r["country"] or "")).replace(",", "，"),
            str(r["score"] or 0),
            str(r["conclusion"] or ""),
            str(r["rbl_hit"] or 0),
            (str(r["abuse"] or "")).replace(",", "，").replace("\n", " "),
        ]
        lines.append(",".join(cols))
    csv = "\ufeff" + "\n".join(lines)
    return PlainTextResponse(
        content=csv,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename=check_history_{int(time.time())}.csv"},
    )
