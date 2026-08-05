"""
业务流程流水线（核心业务引擎）：
  订单支付成功 → 调 Lisa 主机 API（模拟）购买 VPS → 记录 vps_servers → 创建部署任务 deploy_tasks
  → 开启后台线程模拟 vpn.sh 脚本执行 6 步搭建过程
  → 每步回写数据库，完成后生成 VPN 配置、二维码、链接
  → 通过 /internal/deploy/notify 回调接口回传给管理后端（模拟HTTP请求）
"""
import os
import time, random, uuid, threading, json, string
from typing import Dict, Any

try:
    import requests
except Exception:
    requests = None


# 可配置部署输出根：优先 system_configs.vpn_output_root，兜底用 backend 同级 data/output（跨平台相对路径）
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUTPUT_ROOT = os.path.join(BACKEND_DIR, "data", "output")


def _resolve_output_root(cfg_dict: Dict[str, Any]) -> str:
    return (cfg_dict.get("vpn_output_root") or "").strip() or DEFAULT_OUTPUT_ROOT


# ============================================================
# 1. 多供应商云服务器采购（Lisa / Vultr / DigitalOcean 等）
#    - 真实生产：读取 system_configs.{provider}_api_endpoint + key
#    - 本地开发：调用本项目 routers/providers_mock.py 下的 Vultr Mock API
# ============================================================
COUNTRY_TO_VULTR: Dict[str, str] = {
    "US": "ewr", "CA": "tor", "MX": "lax",
    "JP": "nrt", "KR": "sel", "SG": "sgp",
    "HK": "sgp", "TW": "nrt", "IN": "sgp",
    "GB": "lon", "DE": "fra", "FR": "par",
    "NL": "ams", "IT": "fra", "BR": "sao",
    "AU": "syd", "NZ": "syd", "SE": "sto",
}
VULTR_PLAN_TO_SPEC: Dict[str, Dict[str, int]] = {
    "vc2-1c-1gb":  {"cpu": 1, "ram": 1024, "disk": 25},
    "vc2-1c-2gb":  {"cpu": 1, "ram": 2048, "disk": 50},
    "vc2-2c-2gb":  {"cpu": 2, "ram": 2048, "disk": 55},
    "vc2-2c-4gb":  {"cpu": 2, "ram": 4096, "disk": 80},
    "vc2-4c-8gb":  {"cpu": 4, "ram": 8192, "disk": 160},
    "vc2-6c-16gb": {"cpu": 6, "ram": 16384, "disk": 320},
    "vdc-4c-8gb":  {"cpu": 4, "ram": 8192, "disk": 200},
    "vhf-8c-32gb": {"cpu": 8, "ram": 32768, "disk": 512},
}


def _cfg_get(conn, key: str, default: str = "") -> str:
    row = conn.execute("SELECT value FROM system_configs WHERE key=?", (key,)).fetchone()
    return (row["value"] if row and row["value"] is not None else "") or default


def _vultr_via_http(conn, order: dict) -> Dict[str, Any]:
    """通过 HTTP 调用 Vultr Mock（或真实 Vultr）API 下单。
       与生产代码路径完全一致：requests.post(..., headers={'Authorization': 'Bearer API-KEY'})
    """
    endpoint = _cfg_get(conn, "vultr_api_endpoint", "http://localhost:3000/vultr-mock")
    apikey = _cfg_get(conn, "vultr_api_key", "DEMO-VULTR-API-KEY-2026-XXXXXXXXXXXXXXXX")
    if not apikey or apikey.startswith("CHANGEME"):
        # Fallback 到 lisa 逻辑（无 API Key 时不调外部 API，直接本地创建）
        raise RuntimeError("vultr_api_key 未配置，退回 lisa 本地模拟")
    region = COUNTRY_TO_VULTR.get((order.get("country_code") or "US").upper(),
                                  _cfg_get(conn, "vultr_default_region", "ewr"))
    plan = _cfg_get(conn, "vultr_default_plan", "vc2-2c-4gb")
    os_id = int(_cfg_get(conn, "vultr_default_os_id", "1743"))
    # 如果订单里有更明确的规格选择，覆盖默认值（可选：根据 plan/period 估算）
    body = {
        "region": region, "plan": plan, "os_id": os_id,
        "label": f"metoe-order-{order.get('order_no') or int(time.time())}",
        "hostname": f"node-{region}-{order.get('id') or 'x'}.metoe.cloud",
        "ipv6": True, "backups": "disabled",
        "tag": order.get("country_code") or "US",
    }
    if not requests:
        raise RuntimeError("requests 库不可用，无法调用外部采购 API")
    url = endpoint.rstrip("/") + "/v2/instances"
    headers = {"Authorization": f"Bearer {apikey}", "Content-Type": "application/json"}
    r = requests.post(url, json=body, headers=headers, timeout=30)
    if r.status_code >= 400:
        raise RuntimeError(f"Vultr API {r.status_code}: {r.text[:300]}")
    data = r.json()
    ins = data["instance"]
    spec = VULTR_PLAN_TO_SPEC.get(plan, {"cpu": 2, "ram": 4096, "disk": 80})
    return {
        "lisa_order_id": f"VULTR-{order.get('order_no') or ins['id']}",
        "lisa_vps_id": f"VULTR-{ins['id']}",
        "provider": "vultr",
        "region": region,
        "spec": plan,
        "ip": ins["main_ip"],
        "ipv6": ins.get("v6_main_ip") or "",
        "ssh_port": ins.get("ssh_port", 22),
        "ssh_user": "root",
        "ssh_password": ins["default_password"],     # Vultr 创建时只返回一次密码
        "os": ins.get("os", "Ubuntu 22.04 LTS"),
        "cpu_cores": int(spec["cpu"]),
        "ram_mb": int(spec["ram"]),
        "disk_gb": int(spec["disk"]),
        "bandwidth_mbps": 1000,
        "price_month": float(ins.get("monthly_cost", 20.0)),
        "_raw_instance": ins,    # 调试时保留原始 API 返回
    }


def provider_create_server(conn, order, user) -> Dict[str, Any]:
    """
    统一入口：根据 default_provider 配置决定走哪个云服务商采购 API：
      - vultr           → 调用 /vultr-mock/v2/instances（HTTP，与生产一致）
      - digitalocean/do → 走 Vultr 同一 mock（或扩展 DO 路由）
      - lisa/其他       → 走本地模拟（原 lisa_host_buy_server）
    """
    provider = (_cfg_get(conn, "default_provider", "vultr") or "vultr").lower()
    # 订单里可以指定 provider（若未指定用全局默认）
    order_provider = (order.get("provider") or order.get("lisa_provider") or "").lower()
    if order_provider in ("vultr", "digitalocean", "do", "linode", "lisa"):
        provider = order_provider
    try:
        if provider in ("vultr", "digitalocean", "do"):
            return _vultr_via_http(conn, order)
    except Exception as e:
        # 采购失败自动 fallback 到本地 Lisa 模拟（保证测试/演示环境仍可跑通）
        import sys
        print(f"[pipeline] 提供商 {provider} 采购失败: {type(e).__name__}: {e}  → 退回 lisa 本地模拟",
              file=sys.stderr)
    # fallback: Lisa 本地模拟
    return lisa_host_buy_server(conn, order, user)


def _rand_letters(n: int) -> str:
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))


def lisa_host_buy_server(conn, order, user) -> Dict[str, Any]:
    """
    模拟调用 Lisa 主机 API 创建 VPS。
    真实生产中应使用 system_configs 里的 lisa_api_endpoint + lisa_api_key + lisa_api_secret 鉴权。
    """
    # 读取规格配置
    cfg = {}
    for row in conn.execute(
        "SELECT key, value FROM system_configs WHERE key IN ('lisa_default_spec','lisa_default_os','lisa_api_endpoint')"
    ).fetchall():
        cfg[row["key"]] = row["value"] or ""
    region_map = {
        "US": "us-east-1", "CA": "us-west-1", "MX": "us-south-1",
        "JP": "ap-northeast-1", "KR": "ap-northeast-2", "SG": "ap-southeast-1",
        "HK": "ap-east-1", "TW": "ap-southeast-2", "IN": "ap-south-1",
        "GB": "eu-west-2", "DE": "eu-central-1", "FR": "eu-west-3",
        "NL": "eu-west-4", "IT": "eu-south-1", "BR": "sa-east-1",
        "AU": "ap-southeast-3",
    }
    country = (order.get("country_code") or "US").upper()
    region = region_map.get(country, f"auto-{country.lower()}")
    spec = order.get("spec") or cfg.get("lisa_default_spec") or "1c1g25g1t"
    os_name = cfg.get("lisa_default_os") or "Ubuntu 22.04 LTS"

    # 模拟接口耗时
    time.sleep(0.5 if random.random() > 0.2 else 1.2)

    # 生成模拟的 Lisa VPS 信息
    oct2, oct3 = random.randint(10, 240), random.randint(2, 250)
    oct1_map = {"US": 104, "JP": 103, "DE": 138, "GB": 45, "SG": 139, "KR": 125, "HK": 156, "FR": 195, "NL": 185, "AU": 101}
    ip = f"{oct1_map.get(country, random.choice([38,45,103,104,138,139,185,195]))}.{oct2}.{oct3}.{random.randint(10,250)}"
    ipv6 = f"2606:4700:303{random.randint(0,9)}:{random.randint(10,99)}::{random.randint(100,9999)}"
    ssh_pwd = _rand_letters(12)
    lisa_vps_id = f"VPS-LISA-{int(time.time())%100000}-{_rand_letters(4)}"
    lisa_order_id = f"LO{int(time.time())}{random.randint(100,999)}"

    return {
        "lisa_order_id": lisa_order_id,
        "lisa_vps_id": lisa_vps_id,
        "provider": "lisa",
        "region": region,
        "spec": spec,
        "ip": ip,
        "ipv6": ipv6,
        "ssh_port": 22,
        "ssh_user": "root",
        "ssh_password": ssh_pwd,
        "os": os_name,
        "cpu_cores": int(spec[0]) if spec[0].isdigit() else 1,
        "ram_mb": (int(spec[1]) if spec[1].isdigit() else 1) * 1024,
        "disk_gb": 25 if "25" in spec else (50 if "50" in spec else 20),
        "bandwidth_mbps": 1000 if "g1t" in spec.lower() or "1t" in spec.lower() else 500,
        "price_month": float(order.get("lisa_price") or round(5.99 + random.random() * 18, 2)),
    }


# ============================================================
# 2. 模拟 WireGuard 配置 + 二维码
# ============================================================
def _generate_wireguard(server_ip: str, listen_port: int, idx: int):
    server_priv = _rand_letters(43) + "="
    server_pub = _rand_letters(43) + "="
    client_priv = _rand_letters(43) + "="
    client_pub = _rand_letters(43) + "="
    client_ip = f"10.7.{random.randint(1,200)}.{idx + 2}"
    qr_data = (
        f"wg://{client_ip}/?pk={server_pub}&ep={server_ip}:{listen_port}"
        f"&dns=8.8.8.8&aip={client_ip}/24&mtu=1420&ka=25&preshared_key=&name=metoe-wg-{idx}"
    )
    conf = f"""[Interface]
PrivateKey = {client_priv}
Address = {client_ip}/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = {server_pub}
Endpoint = {server_ip}:{listen_port}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
"""
    return {
        "client_ip": client_ip,
        "client_priv": client_priv,
        "client_pub": client_pub,
        "server_pub": server_pub,
        "server_priv": server_priv,
        "qr_data": qr_data,
        "config_content": conf,
    }


# ============================================================
# 3. 触发：支付成功 → 买VPS → 写库 → 启动模拟部署线程
# ============================================================
def trigger_lisa_and_deploy(conn, order_id: int, user) -> Dict[str, Any]:
    """付款完成后立即调用：Lisa主机下单+写服务器表+创建proxy+deploy任务+启动部署线程"""
    order_row = conn.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone()
    if not order_row:
        raise ValueError(f"订单 {order_id} 不存在")
    order = dict(order_row)

    # Step A: 根据配置选择 Lisa / Vultr / DO 供应商 → 调用采购 API（统一入口，HTTP 调用 Vultr 模拟 API）
    vps = provider_create_server(conn, order, user)
    # 更新 order 记录 lisa 信息
    conn.execute(
        "UPDATE orders SET lisa_order_id=?, lisa_provider=?, lisa_region=?, lisa_spec=?, lisa_price=?, deploy_status='provisioning', updated_at=datetime('now','localtime') WHERE id=?",
        (vps["lisa_order_id"], vps["provider"], vps["region"], vps["spec"], vps["price_month"], order_id),
    )

    # Step B: 写入 vps_servers
    one_month_later = time.strftime("%Y-%m-%d", time.localtime(time.time() + 86400 * 30))
    usage_raw = (order.get("usage") or order.get("category") or order.get("lisa_usage") or "ecom").lower()
    usage_map = {
        "web":"web","site":"web","blog":"web","seo":"web","wordpress":"web",
        "chrome":"ecom","cloud-vps":"ecom","ec":"ecom","cross-border":"ecom","shopify":"ecom","shop":"ecom","tiktok":"ecom","fb":"ecom","ecom":"ecom",
        "office":"office","oa":"office","crm":"office","erp":"office",
        "dev":"dev","devops":"dev","ci":"dev","jenkins":"dev","git":"dev","build":"dev",
        "data":"data","ai":"data","train":"data","gpu":"data","isp":"data","dc":"data","compute":"data","analysis":"data","bigdata":"data",
        "game":"game","mc":"game","gaming":"game","steam":"game",
    }
    usage = usage_map.get(usage_raw, "ecom")
    server_id = conn.execute(
        """INSERT INTO vps_servers
           (user_id, order_id, lisa_vps_id, provider, region, spec, ip, ipv6, ssh_port, ssh_user, ssh_password,
            os, cpu_cores, ram_mb, disk_gb, bandwidth_mbps, price_month, status, expire_at, usage, entry_url, qr_code)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'provisioning', ?, ?, NULL, NULL)""",
        (order["user_id"], order_id, vps["lisa_vps_id"], vps["provider"], vps["region"], vps["spec"],
         vps["ip"], vps["ipv6"], vps["ssh_port"], vps["ssh_user"], vps["ssh_password"],
         vps["os"], vps["cpu_cores"], vps["ram_mb"], vps["disk_gb"], vps["bandwidth_mbps"], vps["price_month"],
         one_month_later, usage),
    ).lastrowid

    # Step C: 创建 deploy_tasks
    vpn_port = 51820 + (order_id % 30)
    task_no = f"DEP{int(time.time()*1000)}{random.randint(1000,9999)}"
    cfg = {}
    for row in conn.execute(
        "SELECT key, value FROM system_configs WHERE key IN ('vpn_default_type','vpn_output_root','deploy_auto_start','deploy_timeout_min','callback_api_domain','callback_api_path','callback_api_token','vpn_shell_path')"
    ).fetchall():
        cfg[row["key"]] = row["value"] or ""
    output_root = _resolve_output_root(cfg)
    deploy_id = conn.execute(
        """INSERT INTO deploy_tasks
           (task_no, user_id, order_id, server_id, status, step, total_steps, progress, current_phase,
            vpn_type, vpn_listen_port, vpn_dns, output_root, nginx_server_name, nginx_port, started_at, log_text)
           VALUES (?,?,?,?,0,6,0,'waiting','waiting','wireguard',?, '8.8.8.8',?, '_',80, datetime('now','localtime'), '')""",
        (task_no, order["user_id"], order_id, server_id, vpn_port, output_root),
    ).lastrowid

    # Step D: 创建 proxies 记录（status = deploying）
    plan = order.get("plan") or "standard"
    traffic_map = {"trial": 100, "standard": 500, "pro": 2000, "ultra": 10000}
    traffic_total = traffic_map.get(plan.lower() if isinstance(plan, str) else "standard", 500)
    username = f"u{order['user_id']}_{random.randint(1000,9999)}"
    password = _rand_letters(8)
    http_port = 10800 + (order_id % 2000)
    proxy_id = conn.execute(
        """INSERT INTO proxies
           (user_id, category, country_code, country_name, country_flag, type, protocol,
            ip, port, username, password, traffic_used, traffic_total, threads_limit,
            auth_type, status, expire_at, order_id, server_id, deploy_task_id)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (order["user_id"], order.get("category") or "ISP",
         order.get("country_code") or "US", order.get("country_name") or "", order.get("country_flag") or "",
         order.get("category") or "ISP", "HTTP,SOCKS5",
         vps["ip"], http_port, username, password, 0, traffic_total, 100,
         "pwd", "deploying", one_month_later,
         order_id, server_id, deploy_id),
    ).lastrowid
    conn.execute("UPDATE orders SET remark=? WHERE id=?",
                 (f"proxy_id={proxy_id}, server_id={server_id}, deploy_id={deploy_id}", order_id))

    # Step E: 启动部署模拟后台线程（不阻塞HTTP响应
    auto_start = cfg.get("deploy_auto_start") != "0"
    if auto_start:
        latest_dir = os.path.join(output_root, f"{time.strftime('%Y%m%d')}-{deploy_id}").replace("\\", "/")
        deploy_ctx = {
            "deploy_id": deploy_id,
            "task_no": task_no,
            "user_id": order["user_id"],
            "order_id": order_id,
            "server_id": server_id,
            "proxy_id": proxy_id,
            "server_ip": vps["ip"],
            "ssh_user": vps["ssh_user"],
            "ssh_password": vps["ssh_password"],
            "ssh_port": vps["ssh_port"],
            "vpn_port": vpn_port,
            "output_root": output_root,
            "latest_dir": latest_dir,
            "configs": cfg,
            "country_code": order.get("country_code"),
            "db_path": None,  # 线程里会重新用database.get_conn（SQLite 是文件锁，没问题）
        }
        t = threading.Thread(target=_run_deploy_simulation, args=(deploy_ctx,), daemon=True)
        t.start()
    return {
        "deploy_id": deploy_id,
        "task_no": task_no,
        "server_id": server_id,
        "proxy_id": proxy_id,
        "vps_ip": vps["ip"],
    }


def run_deploy_only(conn, order, user, server_id=None):
    """对于已有服务器，重新部署（替换旧 deploy 任务）"""
    server = conn.execute("SELECT * FROM vps_servers WHERE id=?", (server_id,)).fetchone()
    if not server:
        raise ValueError(f"服务器 {server_id} 不存在")
    order_id = order["id"]
    task_no = f"DEP{int(time.time()*1000)}{random.randint(1000,9999)}"
    vpn_port = 51820 + ((server_id or 1) % 30)
    cfg = {}
    for row in conn.execute(
        "SELECT key, value FROM system_configs WHERE key IN ('vpn_output_root','deploy_auto_start','deploy_timeout_min','callback_api_domain','callback_api_path','callback_api_token')"
    ).fetchall():
        cfg[row["key"]] = row["value"] or ""
    output_root = _resolve_output_root(cfg)
    deploy_id = conn.execute(
        """INSERT INTO deploy_tasks
           (task_no, user_id, order_id, server_id, status, step, total_steps, progress, current_phase,
            vpn_type, vpn_listen_port, vpn_dns, output_root, nginx_server_name, nginx_port, started_at, log_text)
           VALUES (?,?,?,?,0,6,0,'waiting','waiting','wireguard',?, '8.8.8.8',?, '_',80, datetime('now','localtime'), '')""",
        (task_no, order["user_id"], order_id, server_id, vpn_port, output_root),
    ).lastrowid
    conn.execute(
        "UPDATE proxies SET deploy_task_id=?, status='deploying', updated_at=datetime('now','localtime') WHERE server_id=?",
        (deploy_id, server_id),
    )
    latest_dir = os.path.join(output_root, f"{time.strftime('%Y%m%d')}-{deploy_id}").replace("\\", "/")
    deploy_ctx = {
        "deploy_id": deploy_id, "task_no": task_no,
        "user_id": order["user_id"], "order_id": order_id, "server_id": server_id,
        "server_ip": server["ip"], "ssh_user": server["ssh_user"], "ssh_password": server["ssh_password"],
        "ssh_port": server["ssh_port"], "vpn_port": vpn_port,
        "output_root": output_root,
        "latest_dir": latest_dir,
        "configs": cfg,
    }
    t = threading.Thread(target=_run_deploy_simulation, args=(deploy_ctx,), daemon=True)
    t.start()
    return {"deploy_id": deploy_id, "task_no": task_no, "server_id": server_id}


# ============================================================
# 4. 模拟部署线程（6步，逐步更新数据库）
# ============================================================
STEPS = [
    (1, "connect_ssh", "[1/6] 正在通过 SSH 连接 VPS…"),
    (2, "install_packages", "[2/6] 正在执行 apt update 并安装 wireguard-tools / nginx / qrencode…"),
    (3, "config_firewall", "[3/6] 正在启用 IPv4/IPv6 转发、配置防火墙规则…"),
    (4, "gen_wireguard", "[4/6] 正在生成 WireGuard 密钥对与服务器配置 wg0.conf…"),
    (5, "start_services", "[5/6] 正在启动 wireguard 接口 wg0 与 nginx 服务…"),
    (6, "render_qr", "[6/6] 正在生成客户端 .conf + 二维码并发布至下载页…"),
]


def _append_log(conn, deploy_id: int, text: str):
    if not text:
        return
    row = conn.execute("SELECT log_text FROM deploy_tasks WHERE id=?", (deploy_id,)).fetchone()
    old = (row["log_text"] or "") if row else ""
    new = (old.rstrip() + "\n" + text).strip()[:8000]
    conn.execute("UPDATE deploy_tasks SET log_text=?, updated_at=datetime('now','localtime') WHERE id=?", (new, deploy_id))


def _run_deploy_simulation(ctx):
    from core.database import get_conn
    deploy_id = ctx["deploy_id"]
    server_ip = ctx["server_ip"]
    vpn_port = ctx["vpn_port"]
    latest_dir = ctx["latest_dir"]
    order_id = ctx["order_id"]
    proxy_id = ctx["proxy_id"]
    server_id = ctx["server_id"]
    task_no = ctx["task_no"]
    user_id = ctx["user_id"]
    try:
        with get_conn() as conn:
            conn.execute(
                "UPDATE deploy_tasks SET status='running', updated_at=datetime('now','localtime') WHERE id=?",
                (deploy_id,),
            )
            conn.execute(
                "UPDATE vps_servers SET status='deploying', updated_at=datetime('now','localtime') WHERE id=?",
                (server_id,),
            )
        for idx, (step, phase, desc) in enumerate(STEPS):
            with get_conn() as conn:
                conn.execute(
                    "UPDATE deploy_tasks SET step=?, progress=?, current_phase=?, updated_at=datetime('now','localtime') WHERE id=?",
                    (step, int((idx / max(1, len(STEPS))) * 80), phase, deploy_id),
                )
                _append_log(conn, deploy_id, f"{desc} running")
            time.sleep(1.5 + random.random() * 1.5)
            with get_conn() as conn:
                _append_log(conn, deploy_id, f"{desc} OK ({random.randint(1, 50)}s)")
        # ===== 6步完成：生成 WireGuard 配置 =====
        wg = _generate_wireguard(server_ip, vpn_port, deploy_id)
        vpn_url = f"http://{server_ip}/{latest_dir.split('/')[-1]}/wireguard-client-{deploy_id}.png"
        qr_code = wg["qr_data"]
        config_path = f"{latest_dir}/wireguard-client-{deploy_id}.conf"
        # 生成 VPN 下载目录（latest 链接路径
        latest_link = f"{ctx['output_root']}/latest"
        # 写库：deploy_tasks + proxies
        with get_conn() as conn:
            conn.execute(
                """UPDATE deploy_tasks
                   SET status='success', step=6, progress=100, current_phase='done',
                       vpn_url=?, vpn_qr_code=?, vpn_config_path=?, vpn_config_content=?,
                       vpn_client_ip=?, vpn_client_privkey=?, vpn_client_pubkey=?,
                       latest_dir=?, finished_at=datetime('now','localtime'), updated_at=datetime('now','localtime')
                WHERE id=?""",
                (vpn_url, qr_code, config_path, wg["config_content"],
                 wg["client_ip"], wg["client_priv"], wg["client_pub"],
                 latest_dir, deploy_id),
            )
            conn.execute(
                """UPDATE proxies
                   SET vpn_url=?, vpn_qr_code=?, vpn_config_path=?, vpn_config_content=?, status='active',
                       updated_at=datetime('now','localtime')
                WHERE id=?""",
                (vpn_url, qr_code, config_path, wg["config_content"], proxy_id),
            )
            conn.execute(
                """UPDATE vps_servers
                       SET status='active',
                           entry_url=?,
                           qr_code=?,
                           updated_at=datetime('now','localtime')
                     WHERE id=?""",
                (vpn_url, qr_code, server_id),
            )
            conn.execute(
                "UPDATE orders SET deploy_status='done', updated_at=datetime('now','localtime') WHERE id=?",
                (order_id,),
            )
            _append_log(conn, deploy_id,
                        "\n>>> DEPLOY SUCCESS 部署完成\n"
                        f">>> VPN 下载地址: http://{server_ip}/{latest_dir.split('/')[-1]}/\n"
                        f">>> 配置文件: {config_path}\n"
                        f">>> 客户端 VPN IP: {wg['client_ip']}")
            # ===== 回调管理后端 API（保存配置 =========
            cb_domain = (ctx.get("configs") or {}).get("callback_api_domain")
            cb_path = (ctx.get("configs") or {}).get("callback_api_path", "/api/internal/deploy/notify")
            cb_token = (ctx.get("configs") or {}).get("callback_api_token", "")
            if cb_domain and not cb_domain.startswith("https://admin-api.metoe"):
                cb_url = cb_domain.rstrip("/") + cb_path
                # 模拟回调：实际用 requests.post(cb_url, json=payload, headers={'Authorization': cb_token})
                # 这里也同步调用本地同接口（便于本地演示保存到同一个数据库
                try:
                    if requests:
                        payload = {
                            "task_no": task_no, "status": "success", "vpn_type": "wireguard",
                            "vpn_url": vpn_url, "vpn_qr_code": qr_code,
                            "vpn_config_path": config_path, "vpn_config_content": wg["config_content"],
                            "vpn_client_ip": wg["client_ip"], "vpn_client_privkey": wg["client_priv"],
                            "vpn_client_pubkey": wg["client_pub"], "vpn_server_pubkey": wg["server_pub"],
                            "vpn_listen_port": vpn_port, "vpn_dns": "8.8.8.8",
                            "output_root": ctx["output_root"], "latest_dir": latest_dir,
                            "nginx_server_name": "_", "nginx_port": 80,
                            "log_tail": "[deploy-pipeline] Callback from simulation thread",
                        }
                        headers = {"Authorization": cb_token, "Content-Type": "application/json"}
                        # 回调：如果domain是真实外网，就直接POST；否则本地直接调，我们跳过http调用
                        # 因为本地直接写库了，所以这里仅把请求记录到日志即可。
                        cb_status = "skipped-local"
                        cb_resp = json.dumps({"local": True, "payload_keys": list(payload.keys())}, ensure_ascii=False)
                        conn.execute(
                            "UPDATE deploy_tasks SET callback_url=?, callback_status=?, callback_response=? WHERE id=?",
                            (cb_url, cb_status, cb_resp[:2000], deploy_id),
                        )
                except Exception as _e:
                    conn.execute(
                        "UPDATE deploy_tasks SET callback_status='error', callback_response=? WHERE id=?",
                        (f"callback err: {_e}", deploy_id),
                    )
    except Exception as e:
        import traceback
        err = f"{type(e).__name__}: {e}\n{traceback.format_exc()[:1500]}"
        try:
            with get_conn() as conn:
                conn.execute(
                    "UPDATE deploy_tasks SET status='failed', current_phase='error', error_msg=?, updated_at=datetime('now','localtime') WHERE id=?",
                    (err[:2000], deploy_id),
                )
                conn.execute(
                    "UPDATE orders SET deploy_status='failed', updated_at=datetime('now','localtime') WHERE id=?",
                    (order_id,),
                )
                conn.execute(
                    "UPDATE proxies SET status='error', updated_at=datetime('now','localtime') WHERE id=?",
                    (proxy_id,),
                )
                conn.execute(
                    "UPDATE vps_servers SET status='error', updated_at=datetime('now','localtime') WHERE id=?",
                    (server_id,),
                )
                _append_log(conn, deploy_id, f"!!! DEPLOY FAILED: {err}")
        except Exception:
            pass
