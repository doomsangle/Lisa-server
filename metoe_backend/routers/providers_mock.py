"""
第三方云服务商采购接口（模拟 Vultr / DigitalOcean / Linode 风格）

参考真实 Vultr API v2:
  POST   /v2/instances                下单（创建实例）
  GET    /v2/instances                查询所有实例
  GET    /v2/instances/{instance-id}  查询单个实例
  DELETE /v2/instances/{instance-id}  销毁实例
  GET    /v2/regions                  区域列表
  GET    /v2/plans                    套餐列表
  GET    /v2/os                       操作系统列表

模拟返回字段：
  - main_ip        (云服务器公网IP)
  - default_password  (root密码，创建时返回一次)
  - vcpu_count / ram / disk  (硬件规格)
  - os / region / plan   (元信息)
  - status: pending → active （模拟实例启动耗时）

生产环境建议：
  1) 用 system_configs.vultr_api_endpoint + vultr_api_key 替换本 Mock
  2) 在 services/pipeline.py 中通过 _provider_create() 统一调度
  3) 真实 API Key / Secret 走加密配置或环境变量注入
"""
from __future__ import annotations
import time, random, string, json
from typing import Optional, List, Dict, Any
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from pydantic import BaseModel, Field

router = APIRouter(prefix="/vultr-mock", tags=["第三方服务商API (Vultr / DigitalOcean 风格)"])

# ---------------------------------------------------------------
# 内存存储（模拟；生产用 DB）
# ---------------------------------------------------------------
_INSTANCES: Dict[str, Dict[str, Any]] = {}


def _rand(n: int) -> str:
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))


def _rand_ipv4(country: str) -> str:
    oct1_map = {
        "us": 104, "sg": 139, "jp": 103, "de": 138, "gb": 45,
        "nl": 185, "fr": 195, "kr": 125, "au": 101, "hk": 156,
        "sgp": 139, "fra": 138, "lon": 45, "ams": 185, "syd": 101,
        "tok": 103, "sel": 125,
    }
    c = (country or "us").lower()[:2]
    fallback = oct1_map.get((country or "us").lower()[:3], random.choice([38, 45, 103, 104, 138, 139, 185, 195]))
    o1 = oct1_map.get(c, fallback)
    return f"{o1}.{random.randint(8, 240)}.{random.randint(3, 250)}.{random.randint(6, 252)}"


# ---------------------------------------------------------------
# 数据模型（Pydantic DTO 对齐官方 Vultr v2）
# ---------------------------------------------------------------
REGIONS = [
    {"id": "ewr",  "country": "US", "city": "New Jersey",   "continent": "North America"},
    {"id": "ord",  "country": "US", "city": "Chicago",      "continent": "North America"},
    {"id": "lax",  "country": "US", "city": "Los Angeles","continent": "North America"},
    {"id": "atl",  "country": "US", "city": "Atlanta",    "continent": "North America"},
    {"id": "sjc",  "country": "US", "city": "Silicon Valley","continent": "North America"},
    {"id": "dfw",  "country": "US", "city": "Dallas",     "continent": "North America"},
    {"id": "sea",  "country": "US", "city": "Seattle",    "continent": "North America"},
    {"id": "mia",  "country": "US", "city": "Miami",      "continent": "North America"},
    {"id": "tor",  "country": "CA", "city": "Toronto",    "continent": "North America"},
    {"id": "lon",  "country": "GB", "city": "London",     "continent": "Europe"},
    {"id": "fra",  "country": "DE", "city": "Frankfurt",  "continent": "Europe"},
    {"id": "ams",  "country": "NL", "city": "Amsterdam",  "continent": "Europe"},
    {"id": "par",  "country": "FR", "city": "Paris",      "continent": "Europe"},
    {"id": "sto",  "country": "SE", "city": "Stockholm",  "continent": "Europe"},
    {"id": "cdg",  "country": "FR", "city": "Paris",      "continent": "Europe"},
    {"id": "nrt",  "country": "JP", "city": "Tokyo",      "continent": "Asia"},
    {"id": "sgp",  "country": "SG", "city": "Singapore",  "continent": "Asia"},
    {"id": "sel",  "country": "KR", "city": "Seoul",      "continent": "Asia"},
    {"id": "hnd",  "country": "JP", "city": "Tokyo",      "continent": "Asia"},
    {"id": "icn",  "country": "KR", "city": "Seoul",      "continent": "Asia"},
    {"id": "syd",  "country": "AU", "city": "Sydney",     "continent": "Oceania"},
    {"id": "mel",  "country": "AU", "city": "Melbourne",  "continent": "Oceania"},
    {"id": "sao",  "country": "BR", "city": "Sao Paulo",  "continent": "South America"},
]

PLANS = [
    {"id": "vc2-1c-1gb",  "vcpu_count": 1, "ram": 1024,  "disk": 25,  "bandwidth_gb": 1000, "monthly_cost": 5.00,   "type": "vc2"},
    {"id": "vc2-1c-2gb",  "vcpu_count": 1, "ram": 2048,  "disk": 50,  "bandwidth_gb": 2000, "monthly_cost": 10.00,  "type": "vc2"},
    {"id": "vc2-2c-2gb",  "vcpu_count": 2, "ram": 2048,  "disk": 55,  "bandwidth_gb": 2000, "monthly_cost": 12.00,  "type": "vc2"},
    {"id": "vc2-2c-4gb",  "vcpu_count": 2, "ram": 4096,  "disk": 80,  "bandwidth_gb": 3000, "monthly_cost": 20.00,  "type": "vc2"},
    {"id": "vc2-4c-8gb",  "vcpu_count": 4, "ram": 8192,  "disk": 160, "bandwidth_gb": 4000, "monthly_cost": 40.00,  "type": "vc2"},
    {"id": "vc2-6c-16gb", "vcpu_count": 6, "ram": 16384, "disk": 320, "bandwidth_gb": 5000, "monthly_cost": 80.00,  "type": "vc2"},
    {"id": "vdc-4c-8gb",  "vcpu_count": 4, "ram": 8192,  "disk": 200, "bandwidth_gb": 4000, "monthly_cost": 48.00,  "type": "vdc", "gpu": 1},
    {"id": "vhf-8c-32gb",  "vcpu_count": 8, "ram": 32768, "disk": 512, "bandwidth_gb": 8000, "monthly_cost": 160.00, "type": "vhf"},
]

OS_LIST = [
    {"id": 1743, "name": "Ubuntu 22.04 LTS x64",      "family": "ubuntu",   "arch": "x64"},
    {"id": 2150, "name": "Ubuntu 20.04 LTS x64",      "family": "ubuntu",   "arch": "x64"},
    {"id": 352,  "name": "CentOS 7 x64",              "family": "centos",   "arch": "x64"},
    {"id": 401,  "name": "Debian 11 x64",            "family": "debian",   "arch": "x64"},
    {"id": 446,  "name": "Debian 12 x64",            "family": "debian",   "arch": "x64"},
    {"id": 1299, "name": "Rocky Linux 9 x64",        "family": "rocky",    "arch": "x64"},
    {"id": 2061, "name": "AlmaLinux 9 x64",           "family": "alma",     "arch": "x64"},
    {"id": 2007, "name": "Windows Server 2022 x64",    "family": "windows",  "arch": "x64"},
    {"id": 378,  "name": "Fedora 38 x64",             "family": "fedora",   "arch": "x64"},
    {"id": 537,  "name": "Arch Linux x64",            "family": "arch",     "arch": "x64"},
    {"id": 1869, "name": "openSUSE Leap 15.5 x64",   "family": "suse",     "arch": "x64"},
]


class CreateInstanceReq(BaseModel):
    region: str = Field("ewr", description="区域 ID，例如 ewr/lax/sgp/fra/lon")
    plan: str = Field("vc2-1c-1gb", description="套餐 ID")
    os_id: int = Field(1743, description="操作系统 ID (Ubuntu 22.04 LTS = 1743)")
    label: Optional[str] = Field(None, description="实例标签，便于识别")
    hostname: Optional[str] = Field(None, description="主机名")
    tag: Optional[str] = Field(None, description="分组标签")
    ipv6: bool = Field(True, description="启用 IPv6")
    backups: str = Field("disabled", description="disabled / enabled")
    ddos_protection: bool = Field(False)
    user_data: Optional[str] = Field(None, description="Cloud-init 用户数据 (base64)")
    sshkey_id: Optional[str] = Field(None, description="SSH Key ID")
    script_id: Optional[str] = Field(None, description="启动脚本 ID")
    snapshot_id: Optional[str] = Field(None, description="快照 ID")
    reserved_ipv4: Optional[str] = Field(None)
    activation_email: bool = Field(True)
    app_id: Optional[int] = Field(None)
    image_id: Optional[str] = Field(None)
    features: List[str] = Field(default_factory=list)


# ---------------------------------------------------------------
# 辅助：API Key 校验（模拟 Vultr 在 Header 放 Authorization: Bearer APIKEY）
# ---------------------------------------------------------------
def _check_auth(authorization: Optional[str] = Header(None)):
    """模拟 Vultr Bearer token 校验。实际生产中走真实 key。"""
    # Demo Key："Example-Token-VULTR-DEMO"，任何以 VULTR / Bearer 开头都通过
    if not authorization:
        raise HTTPException(status_code=401, detail="Unauthorized.  实际需要: Authorization: Bearer {API_KEY}")
    tok = authorization.replace("Bearer ", "").strip()
    if not tok.startswith(("VULTR", "DEMO", "vultr", "Bearer")) and len(tok) < 8:
        raise HTTPException(status_code=401, detail="Invalid API key (Hint: use DEMO-VULTR-API-KEY-xxxxxxxxxxxx or any Bearer > 8 chars")
    return tok


# ---------------------------------------------------------------
# 区域/套餐/OS 元数据
# ---------------------------------------------------------------
@router.get("/v2/regions")
def list_regions(per_page: int = 100, cursor: Optional[str] = None):
    """Vultr: GET /v2/regions 区域列表"""
    return {"regions": REGIONS, "meta": {"total": len(REGIONS)}}


@router.get("/v2/plans")
def list_plans(type: str = "vc2", per_page: int = 100):
    """Vultr: GET /v2/plans 套餐列表"""
    items = [p for p in PLANS if not type or p.get("type") == type]
    return {"plans": items, "meta": {"total": len(items)}}


@router.get("/v2/os")
def list_os(per_page: int = 100):
    """Vultr: GET /v2/os 操作系统列表"""
    return {"os": OS_LIST, "meta": {"total": len(OS_LIST)}}


@router.get("/v2/account")
def get_account(auth=Depends(_check_auth)):
    """Vultr: 账户信息（用于健康检查）"""
    return {
        "account": {
            "name": "MetoE Demo Account",
            "email": "admin@metoe.io",
            "balance": 9999.99,
            "pending_charges": 0.0,
            "last_payment_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "last_payment_amount": 1000.00,
            "status": "active",
            "api_usage": {"last24h": 127, "last30days": 3841},
            "kimo_stats": None,
        }
    }


# ---------------------------------------------------------------
# 实例 CRUD
# ---------------------------------------------------------------
@router.post("/v2/instances", status_code=202)
def create_instance(req: CreateInstanceReq, auth=Depends(_check_auth)):
    """
    模拟 Vultr 下单创建实例：POST /v2/instances

    关键返回字段：
      instance.id                 云服务器实例 ID（类似 358a...
      instance.main_ip            公网 IPv4
      instance.v6_main_ip          公网 IPv6
      instance.default_password   root 默认密码（仅创建时返回一次
      instance.ssh_port           （Vultr 一般默认为 22）
      instance.os                操作系统名称
      instance.region / plan         区域 / 套餐 ID
      instance.status            新建时 pending（调用 GET 查询后为 active
      instance.vcpu_count, ram, disk 硬件规格
    """
    plan_map = {p["id"]: p for p in PLANS}
    if req.plan not in plan_map:
        hints = ", ".join(p["id"] for p in PLANS[:5])
        raise HTTPException(status_code=400, detail=f"Unknown plan '{req.plan}'. Hint: use {hints}")
    if not any(r["id"] == req.region for r in REGIONS):
        raise HTTPException(status_code=400, detail=f"Unknown region '{req.region}'. Hint: see GET /vultr-mock/v2/regions")
    os_map = {o["id"]: o for o in OS_LIST}
    os = os_map.get(req.os_id, {"id": req.os_id, "name": f"Custom OS {req.os_id}", "family": "linux", "arch": "x64"})
    p = plan_map[req.plan]
    region_obj = next((r for r in REGIONS if r["id"] == req.region), REGIONS[0])

    iid = _rand(13).lower()
    country_for_ip = region_obj["country"]
    ip = _rand_ipv4(country_for_ip)
    ipv6 = f"2400:6180:0000:00d0:0000:0000:{random.randint(1,9999):04x}:{random.randint(1,65535):04x}" if req.ipv6 else ""
    pwd = _rand(16)

    inst = {
        "id": iid,
        "os": os["name"],
        "os_id": req.os_id,
        "ram": p["ram"],
        "disk": p["disk"],
        "main_ip": ip,
        "v6_main_ip": ipv6,
        "v6_network": "",
        "v6_network_size": 64 if ipv6 else 0,
        "internal_ip": "",
        "kvm": "yes",
        "bandwidth": 0,
        "allowed_bandwidth_gb": p["bandwidth_gb"],
        "netmask_v4": "255.255.252.0",
        "gateway_v4": ".".join(ip.split(".")[:3]) + ".1",
        "power_status": "running",
        "server_status": "installingbooting",   # Vultr 真实返回 installingbooting→ok
        "status": "pending",                  # pending → active
        "default_password": pwd,            # 注意：Vultr 只在创建响应里给密码
        "ssh_port": 22,
        "date_created": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "plan": req.plan,
        "vcpu_count": p["vcpu_count"],
        "region": req.region,
        "label": req.label or f"metoe-{iid[:6]}-{req.region}",
        "hostname": req.hostname or f"server-{iid[:8]}.metoe.local",
        "tag": req.tag or "",
        "tags": [req.tag] if req.tag else [],
        "user_scheme": "root",
        "firewall_group_id": "",
        "features": req.features + ([] if not req.ipv6 else ["ipv6"]),
        "backups": req.backups,
        "ddos_protection": req.ddos_protection,
        "monthly_cost": p["monthly_cost"],
    }
    _INSTANCES[iid] = inst
    # 写入时 50 ms 模拟API延时
    time.sleep(0.05 + random.random() * 0.2)
    # 启动后 3 秒后台线程切换 status 为 active（模拟实例启动
    import threading
    def _activate_later():
        time.sleep(2.5 + random.random() * 2.5)
        _INSTANCES[iid]["status"] = "active"
        _INSTANCES[iid]["server_status"] = "ok"
        _INSTANCES[iid]["power_status"] = "running"
        _INSTANCES[iid]["bandwidth"] = round(random.random() * 10, 4)
    threading.Thread(target=_activate_later, daemon=True).start()
    return {"instance": inst}


@router.get("/v2/instances")
def list_instances(
    per_page: int = 100,
    cursor: Optional[str] = None,
    region: Optional[str] = None,
    label: Optional[str] = None,
    tag: Optional[str] = None,
    main_ip: Optional[str] = None,
    auth=Depends(_check_auth),
):
    """Vultr: GET /v2/instances 列出所有实例"""
    items = list(_INSTANCES.values())
    if region: items = [x for x in items if x["region"] == region]
    if label: items = [x for x in items if label.lower() in (x.get("label") or "").lower()]
    if tag: items = [x for x in items if x.get("tag") == tag or tag in (x.get("tags") or [])]
    if main_ip: items = [x for x in items if x["main_ip"] == main_ip]
    return {"instances": items, "meta": {"total": len(items)}}


@router.get("/v2/instances/{instance_id}")
def get_instance(instance_id: str, auth=Depends(_check_auth)):
    """Vultr: GET /v2/instances/{id} 单实例详情"""
    if instance_id not in _INSTANCES:
        raise HTTPException(status_code=404, detail=f"Instance {instance_id} not found")
    return {"instance": _INSTANCES[instance_id]}


@router.patch("/v2/instances/{instance_id}")
def update_instance(instance_id: str, body: dict = {}, auth=Depends(_check_auth)):
    """Vultr: PATCH 实例（改标签/主机名/防火墙等）"""
    if instance_id not in _INSTANCES:
        raise HTTPException(404, "Not found")
    inst = _INSTANCES[instance_id]
    allow = ("label", "hostname", "tag", "firewall_group_id", "user_data", "backups", "ddos_protection")
    for k, v in body.items():
        if k in allow:
            inst[k] = v
    return {"instance": inst}


@router.delete("/v2/instances/{instance_id}", status_code=204)
def delete_instance(instance_id: str, auth=Depends(_check_auth)):
    """Vultr: DELETE /v2/instances/{id} 销毁实例（生产中真扣钱）"""
    if instance_id not in _INSTANCES:
        raise HTTPException(status_code=404, detail=f"Instance {instance_id} not found")
    del _INSTANCES[instance_id]
    return None


@router.post("/v2/instances/{instance_id}/ipv4", status_code=200)
def instance_halt(instance_id: str, auth=Depends(_check_auth)):
    """Vultr: POST /v2/instances/{id}/halt 关机"""
    if instance_id not in _INSTANCES: raise HTTPException(404, "Not found")
    _INSTANCES[instance_id]["power_status"] = "stopped"
    _INSTANCES[instance_id]["status"] = "active"
    return {"status": "ok"}


@router.post("/v2/instances/{instance_id}/start")
def instance_start(instance_id: str, auth=Depends(_check_auth)):
    """Vultr: 开机"""
    if instance_id not in _INSTANCES: raise HTTPException(404, "Not found")
    _INSTANCES[instance_id]["power_status"] = "running"
    return {"status": "ok"}


@router.post("/v2/instances/{instance_id}/reboot")
def instance_reboot(instance_id: str, auth=Depends(_check_auth)):
    """Vultr: 重启"""
    if instance_id not in _INSTANCES: raise HTTPException(404, "Not found")
    _INSTANCES[instance_id]["power_status"] = "running"
    return {"status": "rebooting"}


# ================================================================
# 2. DigitalOcean 风格 Droplets API （为了让模拟更有代表性我们做一个简化版
# 与 Vultr 分开路由，方便用户以后扩展更多云商家
# ================================================================
@router.get("/do/v2/droplets")
def do_list_droplets(auth=Depends(_check_auth)):
    """DigitalOcean: list"""
    drops = []
    for iid, x in _INSTANCES.items():
        drops.append({
            "id": abs(hash(iid)) % (10**10),
            "name": x["label"],
            "memory": x["ram"],
            "vcpus": x["vcpu_count"],
            "disk": x["disk"],
            "region": {"slug": x["region"], "name": next((r["city"] for r in REGIONS if r["id"] == x["region"]), x["region"])},
            "image": {"id": x["os_id"], "name": x["os"]},
            "size": {"slug": x["plan"]},
            "status": x["status"],
            "networks": {
                "v4": [{"type":"public","ip_address":x["main_ip"],"netmask":"255.255.252.0","gateway":".".join(x["main_ip"].split(".")[:3]) + ".1"}],
                "v6": [{"type":"public","ip_address":x["v6_main_ip"],"netmask":64,"gateway":""}] if x.get("v6_main_ip") else []
            },
            "created_at": x["date_created"],
        })
    return {"droplets": drops, "links": {}}


# ================================================================
# 3. 通用供应商下单代理网关（多供应商统一入口）
#    由 services/pipeline.py 在未来可直接调这个：
#    POST /vultr-mock/provider/create  统一 JSON: {provider, region, plan, os_id, ...}
#    可用于 Lisa / vultr / digitalocean 等
# ================================================================
class UnifiedBuyReq(BaseModel):
    provider: str = Field("vultr", description="服务商: lisa / vultr / digitalocean / linode")
    region: str = "ewr"
    plan: str = "vc2-2c-4gb"
    os_id: int = 1743
    country_code: Optional[str] = None
    label: Optional[str] = None
    quantity: int = 1
    ipv6: bool = True


@router.post("/provider/create")
def unified_buy(req: UnifiedBuyReq, x_correlation_id: Optional[str] = Header(None)):
    """通用下单代理（provider 统一入口 → 内部调用对应供应商 Mock API

    返回：
        ip/username/password/ssh_port 标准化
    """
    # 统一用 requests 在本地模拟直接内部调用 Vultr
    from core.database import get_conn
    # 兼容：Lisa 本地直接调用 pipeline.lisa_host_buy_server
    # Vultr：直接复用上面的 create_instance
    if req.provider.lower() in ("vultr", "digitalocean", "do"):
        # 本地 HTTP 调自己（避免重复逻辑），
        body = CreateInstanceReq(
            region=req.region, plan=req.plan, os_id=req.os_id,
            label=req.label or f"metoe-{req.provider[:3]}-{int(time.time())}",
            ipv6=req.ipv6, backups="disabled",
        )
        tok = "Bearer DEMO-PROVIDER-GATEWAY"
        r = create_instance(body, tok)
        ins = r["instance"]
        result = {
            "provider": req.provider.lower(),
            "provider_order_id": f"{req.provider[:3].upper()}-{ins['id']}",
            "instance_id": ins["id"],
            "region": ins["region"],
            "spec": req.plan,
            "ip": ins["main_ip"],
            "ipv6": ins["v6_main_ip"],
            "username": "root",
            "password": ins["default_password"],
            "ssh_port": ins.get("ssh_port", 22),
            "os": ins["os"],
            "cpu_cores": ins["vcpu_count"],
            "ram_mb": ins["ram"],
            "disk_gb": ins["disk"],
            "bandwidth_mbps": 1000,
            "price_month": float(ins.get("monthly_cost") or 5.0),
            "status": ins["status"],
            "raw": {"vultr_instance_id": ins["id"]},
        }
        return {"code": 0, "message": f"{req.provider} 下单成功，实例启动中（约 3~5秒后 status=active", "data": result}
    # 否则 fallback 到 lisa 风格（与 services/pipeline.lisa_host_buy_server 等效结果格式）
    return {
        "code": 0,
        "message": f"fallback-lisa（使用 Lisa 供应商（Vultr 以外供应商将在后续版本支持",
        "data": {
            "provider": "lisa",
            "provider_order_id": f"LISA-{int(time.time())}-{_rand(6)}",
            "ip": _rand_ipv4(req.country_code or "US"),
            "ipv6": "",
            "username": "root",
            "password": _rand(14),
            "ssh_port": 22,
            "os": "Ubuntu 22.04 LTS",
            "cpu_cores": 2,
            "ram_mb": 4096,
            "disk_gb": 80,
            "bandwidth_mbps": 500,
            "price_month": 9.99,
            "status": "pending",
        },
    }


# ================================================================
# 4. 常用工具：获取指定国家映射 -> 区域映射 Vultr region_id (根据我们的国家代号 → Vultr region)
# ================================================================
COUNTRY_VULTR_MAP: Dict[str, str] = {
    "US": "ewr", "CA": "tor", "MX": "lax",
    "JP": "nrt", "KR": "sel", "SG": "sgp",
    "HK": "sgp", "TW": "nrt", "IN": "sgp",
    "GB": "lon", "DE": "fra", "FR": "par",
    "NL": "ams", "IT": "fra", "BR": "sao",
    "AU": "syd", "NZ": "syd", "SE": "sto",
}


@router.get("/mapping/country-to-vultr")
def country_vultr_mapping():
    """返回国家代码 → Vultr region ID 映射"""
    return {"code": 0, "data": COUNTRY_VULTR_MAP}
