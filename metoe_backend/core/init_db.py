"""初始化 SQLite：建表 + 种子数据"""
import os
from .database import get_conn
from .security import hash_password
from .config import get_settings

settings = get_settings()

# 跨平台 demo 数据输出根：backend 同级 data/output（相对路径可移植，Windows/Linux 通用）
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEMO_OUTPUT_ROOT = os.path.join(BACKEND_DIR, "data", "output").replace("\\", "/")


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  email_verified INTEGER NOT NULL DEFAULT 0,
  phone TEXT,
  phone_verified INTEGER NOT NULL DEFAULT 0,
  wechat TEXT,
  qq TEXT,
  password_hash TEXT NOT NULL,
  pay_pwd_hash TEXT,
  last_pwd_changed_at TEXT,
  totp_secret TEXT,
  totp_enabled INTEGER NOT NULL DEFAULT 0,
  balance REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  api_key TEXT,
  lang TEXT NOT NULL DEFAULT 'zh-CN',
  theme TEXT NOT NULL DEFAULT 'light',
  timezone TEXT NOT NULL DEFAULT 'Asia/Shanghai',
  density TEXT NOT NULL DEFAULT 'default',
  page_size INTEGER NOT NULL DEFAULT 20,
  sidebar_collapsed INTEGER NOT NULL DEFAULT 0,
  currency TEXT DEFAULT 'CNY',
  settings_json TEXT,
  last_login_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS roles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  protected INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS permissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  group_name TEXT,
  description TEXT
);

CREATE TABLE IF NOT EXISTS user_roles (
  user_id INTEGER NOT NULL,
  role_code TEXT NOT NULL,
  PRIMARY KEY (user_id, role_code),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (role_code) REFERENCES roles(code) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_code TEXT NOT NULL,
  permission_code TEXT NOT NULL,
  PRIMARY KEY (role_code, permission_code),
  FOREIGN KEY (role_code) REFERENCES roles(code) ON DELETE CASCADE,
  FOREIGN KEY (permission_code) REFERENCES permissions(code) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS system_configs (
  key TEXT PRIMARY KEY,
  value TEXT,
  description TEXT,
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  product TEXT NOT NULL,
  category TEXT,
  country_code TEXT,
  country_name TEXT,
  country_flag TEXT,
  qty INTEGER NOT NULL DEFAULT 1,
  plan TEXT,
  period TEXT,
  amount REAL NOT NULL DEFAULT 0,
  discount REAL NOT NULL DEFAULT 0,
  total REAL NOT NULL DEFAULT 0,
  pay_method TEXT DEFAULT 'balance',
  status TEXT NOT NULL DEFAULT 'pending',
  paid_at TEXT,
  lisa_order_id TEXT,
  lisa_provider TEXT,
  lisa_region TEXT,
  lisa_spec TEXT,
  lisa_price REAL,
  deploy_status TEXT DEFAULT 'pending',
  remark TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pay_no TEXT NOT NULL UNIQUE,
  order_id INTEGER,
  order_no TEXT,
  user_id INTEGER NOT NULL,
  channel TEXT NOT NULL DEFAULT 'mock',
  amount REAL NOT NULL,
  currency TEXT DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'pending',
  channel_txn_id TEXT,
  paid_at TEXT,
  raw_callback TEXT,
  remark TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS vps_servers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  order_id INTEGER,
  proxy_id INTEGER,
  lisa_vps_id TEXT,
  provider TEXT NOT NULL DEFAULT 'lisa',
  region TEXT NOT NULL,
  spec TEXT NOT NULL,
  ip TEXT NOT NULL,
  ipv6 TEXT,
  ssh_port INTEGER DEFAULT 22,
  ssh_user TEXT DEFAULT 'root',
  ssh_password TEXT,
  ssh_key_path TEXT,
  os TEXT DEFAULT 'Ubuntu 22.04 LTS',
  cpu_cores INTEGER DEFAULT 1,
  ram_mb INTEGER DEFAULT 1024,
  disk_gb INTEGER DEFAULT 25,
  bandwidth_mbps INTEGER DEFAULT 100,
  price_month REAL DEFAULT 5.99,
  status TEXT NOT NULL DEFAULT 'provisioning',
  usage TEXT,
  entry_url TEXT,
  qr_code TEXT,
  expire_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS deploy_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_no TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  order_id INTEGER,
  proxy_id INTEGER,
  server_id INTEGER,
  status TEXT NOT NULL DEFAULT 'pending',
  step INTEGER DEFAULT 0,
  total_steps INTEGER DEFAULT 6,
  progress INTEGER DEFAULT 0,
  current_phase TEXT DEFAULT 'waiting',
  log_text TEXT,
  vpn_type TEXT DEFAULT 'wireguard',
  vpn_url TEXT,
  vpn_qr_code TEXT,
  vpn_config_path TEXT,
  vpn_config_content TEXT,
  vpn_client_ip TEXT,
  vpn_client_privkey TEXT,
  vpn_client_pubkey TEXT,
  vpn_listen_port INTEGER DEFAULT 51820,
  vpn_dns TEXT DEFAULT '8.8.8.8',
  output_root TEXT,
  latest_dir TEXT,
  nginx_server_name TEXT,
  nginx_port INTEGER DEFAULT 80,
  started_at TEXT,
  finished_at TEXT,
  error_msg TEXT,
  callback_url TEXT,
  callback_status TEXT,
  callback_response TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (server_id) REFERENCES vps_servers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS proxies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  category TEXT NOT NULL,
  country_code TEXT NOT NULL,
  country_name TEXT,
  country_flag TEXT,
  type TEXT,
  protocol TEXT NOT NULL DEFAULT 'HTTP,SOCKS5',
  ip TEXT NOT NULL,
  port INTEGER NOT NULL,
  username TEXT,
  password TEXT,
  traffic_used REAL NOT NULL DEFAULT 0,
  traffic_total REAL NOT NULL DEFAULT 500,
  threads_limit INTEGER DEFAULT 100,
  auth_type TEXT NOT NULL DEFAULT 'pwd',
  whitelist_ips TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  expire_at TEXT,
  order_id INTEGER,
  server_id INTEGER,
  deploy_task_id INTEGER,
  vpn_url TEXT,
  vpn_qr_code TEXT,
  vpn_config_path TEXT,
  vpn_config_content TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (server_id) REFERENCES vps_servers(id) ON DELETE SET NULL,
  FOREIGN KEY (deploy_task_id) REFERENCES deploy_tasks(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  balance_before REAL,
  balance_after REAL,
  order_id INTEGER,
  payment_id INTEGER,
  remark TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS check_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  ip TEXT NOT NULL,
  country TEXT,
  score INTEGER,
  conclusion TEXT,
  geo TEXT, asn TEXT,
  rbl_hit INTEGER, rbl_total INTEGER,
  abuse TEXT, ipqs TEXT, scamalytic TEXT, spur TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS kyc_verifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'person',
  status TEXT NOT NULL DEFAULT 'pending',
  reject_reason TEXT,
  name TEXT,
  idcard TEXT,
  phone TEXT,
  id_front_url TEXT,
  id_back_url TEXT,
  face_url TEXT,
  company TEXT,
  uscc TEXT,
  legal_name TEXT,
  legal_idcard TEXT,
  bank_account TEXT,
  contact_email TEXT,
  license_url TEXT,
  extra_json TEXT,
  reviewed_by INTEGER,
  reviewed_at TEXT,
  submitted_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_kyc_user ON kyc_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON kyc_verifications(status);

CREATE TABLE IF NOT EXISTS feedbacks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  ref_id TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  unread INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS api_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  key TEXT NOT NULL UNIQUE,
  scopes TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_proxies_user ON proxies(user_id);
CREATE INDEX IF NOT EXISTS idx_proxies_status ON proxies(status);
CREATE INDEX IF NOT EXISTS idx_proxies_server ON proxies(server_id);
CREATE INDEX IF NOT EXISTS idx_proxies_task ON proxies(deploy_task_id);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_no ON orders(order_no);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_vps_user ON vps_servers(user_id);
CREATE INDEX IF NOT EXISTS idx_vps_status ON vps_servers(status);
CREATE INDEX IF NOT EXISTS idx_deploy_user ON deploy_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_deploy_order ON deploy_tasks(order_id);
CREATE INDEX IF NOT EXISTS idx_deploy_server ON deploy_tasks(server_id);
CREATE INDEX IF NOT EXISTS idx_deploy_status ON deploy_tasks(status);
CREATE INDEX IF NOT EXISTS idx_feedback_user ON feedbacks(user_id);
CREATE INDEX IF NOT EXISTS idx_trans_user ON transactions(user_id);

CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  username TEXT,
  action TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'low',
  resource_type TEXT,
  resource_id TEXT,
  old_json TEXT,
  new_json TEXT,
  ip TEXT,
  user_agent TEXT,
  success INTEGER NOT NULL DEFAULT 1,
  summary TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_level ON audit_logs(level);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_logs(resource_type, resource_id);

CREATE TABLE IF NOT EXISTS scheduler_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  func TEXT NOT NULL,
  args TEXT,
  kwargs TEXT,
  trigger TEXT NOT NULL,
  trigger_args TEXT NOT NULL,
  next_run_time TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  last_run_at TEXT,
  last_result TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_scheduler_job_id ON scheduler_jobs(job_id);
CREATE INDEX IF NOT EXISTS idx_scheduler_status ON scheduler_jobs(status);
CREATE INDEX IF NOT EXISTS idx_scheduler_next_run ON scheduler_jobs(next_run_time);

CREATE TABLE IF NOT EXISTS feedback_replies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  feedback_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  username TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  content TEXT NOT NULL,
  attachments TEXT,
  is_internal INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (feedback_id) REFERENCES feedbacks(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_feedback_reply_fid ON feedback_replies(feedback_id);
CREATE INDEX IF NOT EXISTS idx_feedback_reply_uid ON feedback_replies(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_reply_created ON feedback_replies(created_at);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'system',
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'info',
  resource_type TEXT,
  resource_id TEXT,
  is_read INTEGER NOT NULL DEFAULT 0,
  read_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_notification_uid ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notification_created ON notifications(created_at);

CREATE TABLE IF NOT EXISTS proxy_reputation_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proxy_id INTEGER,
  server_id INTEGER,
  ip TEXT NOT NULL,
  ip_ver INTEGER NOT NULL DEFAULT 4,
  country TEXT,
  asn TEXT,
  rbl_hit INTEGER DEFAULT 0,
  rbl_total INTEGER DEFAULT 0,
  abuse_score INTEGER,
  abuse_reports INTEGER,
  ipqs_score INTEGER,
  scamalytic_score INTEGER,
  spur_score INTEGER,
  composite_score INTEGER,
  conclusion TEXT,
  raw_json TEXT,
  snapshot_type TEXT NOT NULL DEFAULT 'daily',
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (proxy_id) REFERENCES proxies(id) ON DELETE SET NULL,
  FOREIGN KEY (server_id) REFERENCES vps_servers(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_rep_proxy ON proxy_reputation_snapshots(proxy_id);
CREATE INDEX IF NOT EXISTS idx_rep_server ON proxy_reputation_snapshots(server_id);
CREATE INDEX IF NOT EXISTS idx_rep_ip ON proxy_reputation_snapshots(ip);
CREATE INDEX IF NOT EXISTS idx_rep_created ON proxy_reputation_snapshots(created_at);
CREATE INDEX IF NOT EXISTS idx_rep_snapshot ON proxy_reputation_snapshots(snapshot_type, created_at);

CREATE TABLE IF NOT EXISTS user_relationships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id INTEGER NOT NULL,
  child_id INTEGER NOT NULL UNIQUE,
  relation_type TEXT NOT NULL DEFAULT 'subaccount',
  permissions TEXT,
  max_balance REAL,
  current_balance REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (child_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_ur_parent ON user_relationships(parent_id);
CREATE INDEX IF NOT EXISTS idx_ur_child ON user_relationships(child_id);
CREATE INDEX IF NOT EXISTS idx_ur_status ON user_relationships(status);

CREATE TABLE IF NOT EXISTS coupons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'percent',
  value REAL NOT NULL,
  min_order REAL NOT NULL DEFAULT 0,
  max_discount REAL,
  usage_limit INTEGER,
  usage_count INTEGER NOT NULL DEFAULT 0,
  applies_to TEXT,
  user_scope TEXT NOT NULL DEFAULT 'all',
  valid_from TEXT,
  valid_until TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_by INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_coupon_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupon_status ON coupons(status);
CREATE INDEX IF NOT EXISTS idx_coupon_valid ON coupons(valid_from, valid_until);

CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  coupon_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  order_id INTEGER,
  code TEXT NOT NULL,
  discount_amount REAL NOT NULL,
  original_amount REAL,
  final_amount REAL,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_redemption_coupon ON coupon_redemptions(coupon_id);
CREATE INDEX IF NOT EXISTS idx_redemption_user ON coupon_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_redemption_order ON coupon_redemptions(order_id);

CREATE TABLE IF NOT EXISTS transfers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transfer_no TEXT NOT NULL UNIQUE,
  from_user_id INTEGER NOT NULL,
  to_user_id INTEGER NOT NULL,
  from_username TEXT,
  to_username TEXT,
  currency TEXT NOT NULL DEFAULT 'CNY',
  amount REAL NOT NULL,
  fee REAL NOT NULL DEFAULT 0,
  type TEXT NOT NULL DEFAULT 'parent_to_child',
  remark TEXT,
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (from_user_id) REFERENCES users(id),
  FOREIGN KEY (to_user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_transfer_from ON transfers(from_user_id);
CREATE INDEX IF NOT EXISTS idx_transfer_to ON transfers(to_user_id);
CREATE INDEX IF NOT EXISTS idx_transfer_status ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_transfer_created ON transfers(created_at);
"""


def init_schema():
    with get_conn() as conn:
        conn.executescript(SCHEMA_SQL)


def seed_data():
    with get_conn() as conn:
        if conn.execute("SELECT COUNT(*) c FROM system_configs").fetchone()["c"] == 0:
            configs = [
                ("site_name", "MetoE 全球云服务器管理平台", "站点名称"),
                ("cs_wechat", "metoe-support", "客服微信号"),
                ("cs_wechat_qr", "", "客服微信二维码URL"),
                ("cs_qq", "88888888", "客服QQ号"),
                ("cs_qq_qr", "", "客服QQ二维码URL"),
                ("cs_email", "support@metoe.io", "客服邮箱"),
                ("cs_phone", "400-888-8888", "客服电话"),
                ("cs_work_time", "周一至周日 09:00-23:00", "客服工作时间"),
                ("cs_group_invite", "https://t.me/metoe_group", "用户群/频道链接"),
                ("lisa_api_endpoint", "https://api.lisa-host.com/v1", "Lisa主机 API 地址"),
                ("lisa_api_key", "sk_lisa_demo_xxxxxxxxxxxxxxxx", "Lisa主机 API Key（模拟）"),
                ("lisa_api_secret", "secret_lisa_demo_yyyyyyyyyyyyy", "Lisa主机 API Secret（模拟）"),
                ("lisa_default_spec", "1c1g25g1t", "Lisa主机默认配置规格"),
                ("lisa_default_os", "Ubuntu 22.04 LTS", "Lisa主机默认操作系统"),
                ("callback_api_domain", "https://admin-api.metoe.io", "管理后端API回调域名（部署结果通知）"),
                ("callback_api_path", "/api/internal/deploy/notify", "回调路径"),
                ("callback_api_token", "Bearer callback_demo_token_zzzzz", "回调鉴权Token"),
                ("node_default_type", "wireguard", "默认节点接入类型: wireguard/openvpn"),
                ("node_nginx_port", "80", "入口页面Nginx端口"),
                ("node_output_root", "/etc/s-box/output", "入口配置根目录"),
                ("node_shell_path", "/opt/s-box/vpn.sh", "初始化脚本路径"),
                ("payment_mock_enabled", "1", "是否启用模拟支付（1是0否）"),
                ("payment_alipay_enabled", "0", "支付宝支付开关"),
                ("payment_wechat_enabled", "0", "微信支付开关"),
                ("payment_usdt_enabled", "1", "USDT支付开关"),
                ("payment_paypal_enabled", "1", "PayPal支付开关"),
                ("paypal_mode", "sandbox", "PayPal 模式：sandbox / live"),
                ("paypal_client_id", "AW-DEMO-PAYPAL-CLIENT-ID-abcdefghijklmnopqrstuvwxyz0123456789", "PayPal 官方 Client ID（模拟）"),
                ("paypal_secret", "EK-DEMO-PAYPAL-SECRET-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", "PayPal 官方 Secret（模拟）"),
                ("paypal_currency", "USD", "PayPal 结算币种（默认USD）"),
                ("paypal_fee_rate", "0.044", "PayPal 手续费率（默认4.4% + $0.3）"),
                ("paypal_fixed_fee_usd", "0.3", "PayPal 固定手续费（美元）"),
                ("usdt_network", "TRC20", "USDT 网络：TRC20 / ERC20 / BEP20"),
                ("usdt_wallet_address", "TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE", "USDT 收款钱包地址（TRC20，模拟）"),
                ("usdt_rate_source", "coinbase", "USDT 汇率来源（模拟）"),
                ("usdt_cny_usd_rate", "7.25", "人民币对美元汇率（模拟：1 USD = 7.25 CNY）"),
                ("usdt_min_confirm", "1", "USDT 最小区块确认数"),
                ("usdt_order_expire_min", "30", "USDT 订单有效时长（分钟）"),
                ("deploy_auto_start", "1", "支付成功是否自动开始部署"),
                ("deploy_timeout_min", "30", "部署超时时间(分钟)"),

                # ============= 第三方云服务商采购（Vultr / DigitalOcean / Linode） =============
                ("providers_enabled", "lisa,vultr,digitalocean", "已启用的供应商（逗号分隔）"),
                ("default_provider", "vultr", "默认下单供应商：lisa / vultr / digitalocean"),
                ("vultr_api_endpoint", "http://localhost:3000/vultr-mock", "Vultr API 端点（生产 https://api.vultr.com）"),
                ("vultr_api_key", "DEMO-VULTR-API-KEY-2026-XXXXXXXXXXXXXXXX", "Vultr API Key（模拟）"),
                ("vultr_default_region", "ewr", "Vultr 默认区域（纽约 New Jersey）"),
                ("vultr_default_plan", "vc2-2c-4gb", "Vultr 默认套餐（2C4G 80G SSD）"),
                ("vultr_default_os_id", "1743", "Vultr 默认操作系统（Ubuntu 22.04 LTS）"),
                ("digitalocean_api_endpoint", "http://localhost:3000/vultr-mock/do", "DigitalOcean API 端点（模拟）"),
                ("digitalocean_api_token", "DEMO-DO-TOKEN-2026-YYYYYYYYYYYYYYYY", "DigitalOcean API Token（模拟）"),
            ]
            conn.executemany(
                "INSERT INTO system_configs (key, value, description) VALUES (?,?,?)", configs
            )

        # ============= 补齐新增的默认配置（INSERT OR IGNORE，不覆盖已有） =============
        # 无论 system_configs 是否为空，都补齐新增的 provider 类配置（便于升级）
        _ensure_configs = [
            ("providers_enabled", "lisa,vultr,digitalocean", "已启用的供应商（逗号分隔）"),
            ("default_provider", "vultr", "默认下单供应商：lisa / vultr / digitalocean"),
            ("vultr_api_endpoint", "http://localhost:3000/vultr-mock", "Vultr API 端点（生产 https://api.vultr.com）"),
            ("vultr_api_key", "DEMO-VULTR-API-KEY-2026-XXXXXXXXXXXXXXXX", "Vultr API Key（模拟）"),
            ("vultr_default_region", "ewr", "Vultr 默认区域（纽约 New Jersey）"),
            ("vultr_default_plan", "vc2-2c-4gb", "Vultr 默认套餐（2C4G 80G SSD）"),
            ("vultr_default_os_id", "1743", "Vultr 默认操作系统（Ubuntu 22.04 LTS ID=1743）"),
            ("digitalocean_api_endpoint", "http://localhost:3000/vultr-mock/do", "DigitalOcean API 端点（模拟）"),
            ("digitalocean_api_token", "DEMO-DO-TOKEN-2026-YYYYYYYYYYYYYYYY", "DigitalOcean API Token（模拟）"),
        ]
        with get_conn() as conn:
            conn.executemany(
                "INSERT OR IGNORE INTO system_configs (key, value, description) VALUES (?,?,?)",
                _ensure_configs,
            )

        if conn.execute("SELECT COUNT(*) c FROM roles").fetchone()["c"] == 0:
            conn.executemany(
                "INSERT INTO roles (code, name, description, protected) VALUES (?,?,?,1)",
                [
                    ("super_admin", "超级管理员", "拥有全部权限"),
                    ("admin", "管理员", "业务管理"),
                    ("finance", "财务", "订单与账单"),
                    ("support", "客服", "反馈与检测"),
                    ("user", "普通用户", "注册默认角色"),
                ],
            )

        if conn.execute("SELECT COUNT(*) c FROM permissions").fetchone()["c"] == 0:
            perm_list = [
                ("dashboard:view", "查看控制台", "控制台"),
                ("nodes:view", "查看节点", "节点产品"),
                ("nodes:manage", "管理节点", "节点产品"),
                ("proxies:view", "查看接入实例", "接入实例"),
                ("proxies:manage", "管理接入实例", "接入实例"),
                ("servers:view", "查看云服务器", "云服务器"),
                ("servers:manage", "管理云服务器", "云服务器"),
                ("deploy:view", "查看部署任务", "部署"),
                ("deploy:run", "执行部署/重部署", "部署"),
                ("orders:create", "下单购买", "订单"),
                ("orders:view", "查看订单", "订单"),
                ("orders:manage", "管理订单", "订单"),
                ("payment:pay", "发起支付", "支付"),
                ("payment:view", "查看支付记录", "支付"),
                ("payment:refund", "退款管理", "支付"),
                ("check:run", "执行检测", "网络检测中心"),
                ("check:history", "查看历史", "网络检测中心"),
                ("kyc:submit", "提交实名认证", "实名认证"),
                ("kyc:view", "查看实名状态", "实名认证"),
                ("kyc:audit", "审核实名认证", "实名认证"),
                ("developer:view", "查看API文档", "开发者"),
                ("developer:key", "生成API Key", "开发者"),
                ("feedback:create", "提交反馈", "反馈"),
                ("feedback:manage", "处理反馈", "反馈"),
                ("config:view", "查看系统配置", "系统"),
                ("config:manage", "修改系统配置", "系统"),
                ("system:users:view", "查看用户", "系统"),
                ("system:users:manage", "管理用户", "系统"),
                ("system:roles:view", "查看角色", "系统"),
                ("system:roles:manage", "管理角色权限", "系统"),
            ]
            conn.executemany(
                "INSERT INTO permissions (code, name, group_name) VALUES (?,?,?)", perm_list
            )

        if conn.execute("SELECT COUNT(*) c FROM role_permissions").fetchone()["c"] == 0:
            all_codes = [r["code"] for r in conn.execute("SELECT code FROM permissions").fetchall()]
            admin_less = [c for c in all_codes if c not in ("system:roles:manage", "config:manage")]
            finance_only = ["dashboard:view", "orders:view", "orders:manage", "payment:view", "payment:refund", "servers:view"]
            support_only = ["dashboard:view", "proxies:view", "servers:view", "deploy:view", "check:run", "check:history", "feedback:manage", "config:view"]
            user_only = ["dashboard:view", "proxies:view", "servers:view", "deploy:view", "deploy:run",
                         "orders:create", "orders:view", "payment:pay", "payment:view",
                         "check:run", "check:history", "developer:view", "developer:key", "feedback:create",
                         "kyc:submit", "kyc:view"]

            def bind(role_code, codes):
                conn.executemany(
                    "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
                    [(role_code, c) for c in codes],
                )

            bind("super_admin", all_codes)
            bind("admin", admin_less)
            bind("finance", finance_only)
            bind("support", support_only)
            bind("user", user_only)

        if conn.execute("SELECT COUNT(*) c FROM users").fetchone()["c"] == 0:
            pwd_hash = hash_password("123456")
            admin_id = conn.execute(
                "INSERT INTO users (username, email, phone, wechat, qq, password_hash, balance) VALUES (?,?,?,?,?,?,?)",
                ("admin", "admin@metoe.io", "13800000001", "lisa_admin001", "10001", pwd_hash, 99999.00),
            ).lastrowid
            support_id = conn.execute(
                "INSERT INTO users (username, email, phone, wechat, qq, password_hash, balance) VALUES (?,?,?,?,?,?,?)",
                ("support", "support@metoe.io", "13800000002", "metoe-support", "88888888", pwd_hash, 0.00),
            ).lastrowid
            demo_id = conn.execute(
                "INSERT INTO users (username, email, phone, wechat, qq, password_hash, balance) VALUES (?,?,?,?,?,?,?)",
                ("demo", "demo@metoe.io", "13900001234", "demo_user_88", "123456789", pwd_hash, 3288.50),
            ).lastrowid

            conn.executemany(
                "INSERT OR IGNORE INTO user_roles (user_id, role_code) VALUES (?,?)",
                [
                    (admin_id, "super_admin"),
                    (admin_id, "admin"),
                    (support_id, "support"),
                    (demo_id, "user"),
                ],
            )

            import random, time, json
            now = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
            one_month_later = time.strftime("%Y-%m-%d", time.localtime(time.time() + 86400*30))

            def create_demo_deploy(uid, country_code, country_name, country_flag, order_idx, ip_suffix4, cat="ISP"):
                order_no = f"PO{int(time.time()*1000) + order_idx*7}"
                pay_no = f"PAY{int(time.time()*1000) + order_idx*7}"
                region_map = {"US": "us-east-1", "JP": "ap-northeast-1", "DE": "eu-central-1",
                              "GB": "eu-west-2", "SG": "ap-southeast-1", "KR": "ap-northeast-2"}
                region = region_map.get(country_code, "us-east-1")
                usage_list = ["web","ecom","office","dev","data","game"]
                usage = usage_list[order_idx % len(usage_list)]

                order_id = conn.execute(
                    """INSERT INTO orders
                       (order_no, user_id, product, category, country_code, country_name, country_flag,
                        qty, plan, period, amount, discount, total, pay_method, status, paid_at,
                        lisa_order_id, lisa_provider, lisa_region, lisa_spec, lisa_price, deploy_status)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'paid', datetime('now','localtime'),
                               ?, 'Lisa主机', ?, '1c1g25g1t', 5.99, 'done')""",
                    (order_no, uid, f"{country_name}云服务器·2核2G·100Mbps·1个月", usage, country_code, country_name, country_flag,
                     1, "standard", "1m", 149.00, 0.00, 149.00, "balance", f"LO{int(time.time())+order_idx*3}", region),
                ).lastrowid

                conn.execute(
                    """INSERT INTO payments
                       (pay_no, order_id, order_no, user_id, channel, amount, currency, status, channel_txn_id, paid_at)
                       VALUES (?,?,?,?,?,?, 'CNY', 'paid', ?, datetime('now','localtime'))""",
                    (pay_no, order_id, order_no, uid, "mock_alipay", 149.00, f"TXN_MOCK_{order_idx}_{int(time.time())}"),
                )

                ip = f"{104 if country_code=='US' else (103 if country_code=='JP' else 138)}.{20+order_idx}.{ip_suffix4}.{80+order_idx}"
                ssh_pwd = "".join(random.choices("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", k=12))
                entry_url = f"http://{ip}/console/login"
                qr_code = f"node://{ip}:80?token=demo{order_idx}"
                server_id = conn.execute(
                    """INSERT INTO vps_servers
                       (user_id, order_id, lisa_vps_id, provider, region, spec, ip, ssh_port, ssh_user, ssh_password,
                        os, cpu_cores, ram_mb, disk_gb, bandwidth_mbps, price_month, status, usage, entry_url, qr_code, expire_at)
                       VALUES (?,?,?,?,?,?,?,22,'root',?, 'Ubuntu 22.04 LTS',2,2048,50,100,149,'active',?,?,?,?)""",
                    (uid, order_id, f"SRV-LISA-{order_idx}-{int(time.time())%10000}", "lisa", region,
                     "2c2g50g100m", ip, ssh_pwd, usage, entry_url, qr_code, one_month_later),
                ).lastrowid

                task_no = f"DEP{int(time.time()*1000) + order_idx*11}"
                vpn_port = 51820 + order_idx
                output_dir = f"{DEMO_OUTPUT_ROOT}/{time.strftime('%Y%m%d')}-{order_idx+1}"
                client_ip = f"10.7.0.{order_idx + 2}"
                client_priv = "yL" + "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789+/=", k=42)) + "="
                client_pub = "oJ" + "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789+/=", k=42)) + "="
                server_pub = "sE" + "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789+/=", k=42)) + "="
                vpn_url = entry_url
                config_path = f"{output_dir}/node-client-{order_idx+1}.conf"
                qr_data = qr_code
                config_content = f"""# 云服务器 #{server_id} 入口配置
# 入口地址：{entry_url}
# 远程连接 IP：{ip}:22
# 账号：root / 密码：{ssh_pwd}
# 节点接入端口：{vpn_port}
"""

                log_t = """[1/6] 连接云服务器 SSH 通道... OK (1.2s)
[2/6] 更新系统软件包并安装基础环境、Nginx... OK (38s)
[3/6] 配置防火墙、远程访问、安全加固... OK (2s)
[4/6] 生成入口密钥对与服务器配置... OK (1s)
[5/6] 启动远程接入接口 wg0 与 Nginx 入口服务... OK (3s)
[6/6] 渲染客户端配置 + 入口二维码 => 发布到入口面板... OK (2s)
>>> 初始化 SUCCESS 总计 48s
>>> 入口访问地址：http://"""+ip+"""/"""+output_dir.split('/')[-1]+"""/
>>> 配置文件："""+config_path+"""
"""

                deploy_id = conn.execute(
                    """INSERT INTO deploy_tasks
                       (task_no, user_id, order_id, server_id, status, step, total_steps, progress, current_phase,
                        log_text, vpn_type, vpn_url, vpn_qr_code, vpn_config_path, vpn_config_content,
                        vpn_client_ip, vpn_client_privkey, vpn_client_pubkey, vpn_listen_port, vpn_dns,
                        output_root, latest_dir, nginx_server_name, nginx_port, started_at, finished_at)
                       VALUES (?,?,?,?,?,6,6,100,'done',?, 'wireguard',?,?,?,?,?,?,?,?,?,
                        ?, ?, '_', 80, datetime('now','-5 minutes','localtime'), datetime('now','-4 minutes','localtime'))""",
                    (task_no, uid, order_id, server_id, "success", log_t,
                     vpn_url, qr_data, config_path, config_content,
                     client_ip, client_priv, client_pub, vpn_port, "8.8.8.8",
                     DEMO_OUTPUT_ROOT, output_dir),
                ).lastrowid

                proxy_id = conn.execute(
                    """INSERT INTO proxies
                       (user_id, category, country_code, country_name, country_flag, type, protocol,
                        ip, port, username, password, traffic_used, traffic_total, threads_limit,
                        auth_type, status, expire_at, order_id, server_id, deploy_task_id,
                        vpn_url, vpn_qr_code, vpn_config_path, vpn_config_content)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (uid, usage, country_code, country_name, country_flag, usage, "HTTP,SOCKS5",
                     ip, 10800+order_idx,
                     f"user_{1000+order_idx}", "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=8)),
                     0, 500, 100, "pwd", "active", one_month_later, order_id, server_id, deploy_id,
                     vpn_url, qr_data, config_path, config_content),
                ).lastrowid

                conn.execute("UPDATE orders SET remark=? WHERE id=?", (f"node_id={proxy_id},server_id={server_id},deploy_id={deploy_id}", order_id))
                return order_id, server_id, deploy_id, proxy_id

            create_demo_deploy(demo_id, "US", "美国", "🇺🇸", 0, 12)
            create_demo_deploy(demo_id, "JP", "日本", "🇯🇵", 1, 45)
            create_demo_deploy(demo_id, "DE", "德国", "🇩🇪", 2, 9)
            create_demo_deploy(demo_id, "GB", "英国", "🇬🇧", 3, 118, "DC")
            create_demo_deploy(demo_id, "SG", "新加坡", "🇸🇬", 4, 220)

            pending_order_no = f"PO{int(time.time()*1000)+900}"
            pending_order_id = conn.execute(
                """INSERT INTO orders
                   (order_no, user_id, product, category, country_code, country_name, country_flag,
                    qty, plan, period, amount, discount, total, pay_method, status, paid_at,
                    lisa_order_id, lisa_provider, lisa_region, lisa_spec, lisa_price, deploy_status)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'paid', datetime('now','-3 minutes','localtime'),
                           'LO_PENDING_01', 'Lisa主机', 'us-west-2', '2c2g50g5t', 11.99, 'deploying')""",
                (pending_order_no, demo_id, "美国云服务器·4核4G·500Mbps·3个月", "data", "US", "美国", "🇺🇸",
                 1, "pro", "3m", 799.00, 96.00, 703.00, "balance"),
            ).lastrowid
            pending_ip = "45.77.102.55"
            pending_server_id = conn.execute(
                """INSERT INTO vps_servers
                   (user_id, order_id, lisa_vps_id, provider, region, spec, ip, ssh_port, ssh_user, ssh_password,
                    os, cpu_cores, ram_mb, disk_gb, bandwidth_mbps, price_month, status, usage)
                   VALUES (?,?,?,?,?,?,?,22,'root','PendPwd_88Xy', 'Ubuntu 22.04 LTS',4,4096,100,500,233,'provisioning','data')""",
                (demo_id, pending_order_id, "SRV-LISA-PENDING-01", "lisa", "us-west-2", "4c4g100g500m", pending_ip),
            ).lastrowid
            pending_task_no = f"DEP{int(time.time()*1000)+700}"
            pending_log = """[1/6] 连接云服务器 SSH 通道... OK (1.8s)
[2/6] 更新系统软件包并安装基础环境... running (22s elapsed, ~18s remaining)
"""
            conn.execute(
                """INSERT INTO deploy_tasks
                   (task_no, user_id, order_id, server_id, status, step, total_steps, progress, current_phase,
                    log_text, vpn_type, vpn_dns, vpn_listen_port, output_root, nginx_server_name, nginx_port, started_at)
                   VALUES (?,?,?,?,?,2,6,33,'installing_base',?, 'wireguard','8.8.8.8',51821,
                    ?,'_',80, datetime('now','-3 minutes','localtime'))""",
                (pending_task_no, demo_id, pending_order_id, pending_server_id, "running", pending_log, DEMO_OUTPUT_ROOT),
            )


def init_all():
    init_schema()
    seed_data()
    run_migrations()


def run_migrations():
    """幂等迁移：现有DB文件补全新增列、回填历史数据、归一化状态枚举。
    每次启动都会调用（通过 PRAGMA + WHERE ... IS NULL 保证重复执行安全）。"""
    with get_conn() as conn:
        # ---------- 1) 补 vps_servers 缺失的 3 个列（ALTER TABLE 只执行一次；后续列继续 append 即可） ----------
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(vps_servers)").fetchall()}
        add_cols = []
        if "usage" not in cur_cols:
            add_cols.append("ADD COLUMN usage TEXT")
        if "entry_url" not in cur_cols:
            add_cols.append("ADD COLUMN entry_url TEXT")
        if "qr_code" not in cur_cols:
            add_cols.append("ADD COLUMN qr_code TEXT")
        for stmt in add_cols:
            conn.execute(f"ALTER TABLE vps_servers {stmt}")

        # ---------- 2) 归一化状态：旧值 'running' → 统一为前端识别的 'active'；deploy_started 使用 'deploying' ----------
        conn.execute("UPDATE vps_servers SET status='active' WHERE status='running'")
        conn.execute("UPDATE vps_servers SET status='provisioning' WHERE status IN ('pending','waiting','new','creating')")
        conn.execute("UPDATE vps_servers SET status='stopped' WHERE status='poweroff'")

        # ---------- 3) 回填 vps_servers.usage 来源：orders.category（购买时记录的场景） ----------
        # orders.category → usageTag 枚举映射 (web/ecom/office/dev/data/game)
        conn.execute("""
            UPDATE vps_servers
               SET usage = CASE
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('web','site','blog','seo','wordpress') THEN 'web'
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('chrome','cloud-vps','ec','cross-border','shopify','shop','tiktok','fb') THEN 'ecom'
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('office','oa','crm','erp') THEN 'office'
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('dev','devops','ci','jenkins','git','build') THEN 'dev'
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('data','ai','train','gpu','ISP','DC','compute','analysis','bigdata') THEN 'data'
                     WHEN (SELECT o.category FROM orders o WHERE o.id = vps_servers.order_id) IN ('game','mc','gaming','steam') THEN 'game'
                     ELSE COALESCE(vps_servers.usage, 'ecom')
                   END
             WHERE usage IS NULL OR usage = ''
        """)

        # ---------- 4) 回填 vps_servers.entry_url / qr_code 来源：每个 server 对应 deploy_tasks 表最新一条成功记录的 vpn_url/vpn_qr_code ----------
        conn.execute("""
            UPDATE vps_servers
               SET entry_url = (
                       SELECT d.vpn_url FROM deploy_tasks d
                        WHERE d.server_id = vps_servers.id
                          AND d.vpn_url IS NOT NULL
                     ORDER BY d.id DESC
                        LIMIT 1
                   )
             WHERE (entry_url IS NULL OR entry_url = '')
               AND EXISTS (SELECT 1 FROM deploy_tasks d WHERE d.server_id = vps_servers.id AND d.vpn_url IS NOT NULL)
        """)
        conn.execute("""
            UPDATE vps_servers
               SET qr_code = (
                       SELECT d.vpn_qr_code FROM deploy_tasks d
                        WHERE d.server_id = vps_servers.id
                          AND d.vpn_qr_code IS NOT NULL
                     ORDER BY d.id DESC
                        LIMIT 1
                   )
             WHERE (qr_code IS NULL OR qr_code = '')
               AND EXISTS (SELECT 1 FROM deploy_tasks d WHERE d.server_id = vps_servers.id AND d.vpn_qr_code IS NOT NULL)
        """)

        # ---------- 5) 保证状态一致：deploy_tasks.success 的 server 若仍 provisioning/deploying → 提为 active ----------
        conn.execute("""
            UPDATE vps_servers
               SET status = 'active',
                   updated_at = datetime('now','localtime')
             WHERE status IN ('provisioning','deploying','installing')
               AND EXISTS (SELECT 1 FROM deploy_tasks d WHERE d.server_id = vps_servers.id AND d.status = 'success')
        """)
        # deploy_tasks.failed → server 标 error
        conn.execute("""
            UPDATE vps_servers
               SET status = 'error',
                   updated_at = datetime('now','localtime')
             WHERE status IN ('provisioning','deploying','running','installing')
               AND EXISTS (SELECT 1 FROM deploy_tasks d WHERE d.server_id = vps_servers.id AND d.status = 'failed')
        """)

        # ---------- 6) 权限码一致性迁移：旧 nodes:view/manage → proxies:view/manage 路由已改名，历史绑定同步替换 ----------
        conn.execute(
            "INSERT OR IGNORE INTO permissions (code, name, group_name) VALUES ('proxies:view','查看接入实例','接入实例')"
        )
        conn.execute(
            "INSERT OR IGNORE INTO permissions (code, name, group_name) VALUES ('proxies:manage','管理接入实例','接入实例')"
        )
        for old_code, new_code in (('nodes:view','proxies:view'),('nodes:manage','proxies:manage')):
            try:
                conn.execute("""
                    INSERT OR IGNORE INTO role_permissions (role_code, permission_code)
                    SELECT rp.role_code, ? FROM role_permissions rp WHERE rp.permission_code = ?
                """, (new_code, old_code))
            except Exception:
                pass
            conn.execute("DELETE FROM role_permissions WHERE permission_code = ?", (old_code,))

        # ---------- 6.5) users 表补个人偏好/安全字段（历史 DB 无这些列时幂等补列）----------
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(users)").fetchall()}
        for col_def in [
            ("email_verified", "INTEGER NOT NULL DEFAULT 0"),
            ("phone_verified", "INTEGER NOT NULL DEFAULT 0"),
            ("pay_pwd_hash", "TEXT"),
            ("last_pwd_changed_at", "TEXT"),
            ("totp_secret", "TEXT"),
            ("totp_enabled", "INTEGER NOT NULL DEFAULT 0"),
            ("lang", "TEXT NOT NULL DEFAULT 'zh-CN'"),
            ("theme", "TEXT NOT NULL DEFAULT 'light'"),
            ("timezone", "TEXT NOT NULL DEFAULT 'Asia/Shanghai'"),
            ("density", "TEXT NOT NULL DEFAULT 'default'"),
            ("page_size", "INTEGER NOT NULL DEFAULT 20"),
            ("sidebar_collapsed", "INTEGER NOT NULL DEFAULT 0"),
            ("currency", "TEXT DEFAULT 'CNY'"),
            ("decimals", "INTEGER NOT NULL DEFAULT 2"),
            ("settings_json", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE users ADD COLUMN {col_def[0]} {col_def[1]}")
        # 回填：有值的邮箱若域名是可信地址，视为已验证（仅历史数据；demo用户邮件发送未启用时默认1方便演示）
        conn.execute("""
            UPDATE users SET email_verified = 1
             WHERE (email_verified IS NULL OR email_verified = 0)
               AND email IS NOT NULL AND email <> ''
               AND (instr(email, '@metoe.io') > 0 OR instr(email, '@example.') > 0 OR instr(email, '@admin.') > 0)
        """)
        # 回填：有值的 11 位手机号且符合中国格式，默认未验证(安全起见不自动标为已验证)，保留 0

        # ---------- 7) 审计日志表：确保表和所有列都存在（老DB没跑新 SCHEMA_SQL 时兜底；PRAGMA + ADD COLUMN 幂等） ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS audit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              username TEXT,
              action TEXT NOT NULL,
              level TEXT NOT NULL DEFAULT 'low',
              resource_type TEXT,
              resource_id TEXT,
              old_json TEXT,
              new_json TEXT,
              ip TEXT,
              user_agent TEXT,
              success INTEGER NOT NULL DEFAULT 1,
              summary TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(audit_logs)").fetchall()}
        add_cols_sql = []
        for col_def in [
            ("user_id", "INTEGER"), ("username", "TEXT"), ("action", "TEXT NOT NULL DEFAULT 'unknown'"),
            ("level", "TEXT NOT NULL DEFAULT 'low'"), ("resource_type", "TEXT"), ("resource_id", "TEXT"),
            ("old_json", "TEXT"), ("new_json", "TEXT"), ("ip", "TEXT"), ("user_agent", "TEXT"),
            ("success", "INTEGER NOT NULL DEFAULT 1"), ("summary", "TEXT"),
            ("created_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                add_cols_sql.append(f"ADD COLUMN {col_def[0]} {col_def[1]}")
        for stmt in add_cols_sql:
            conn.execute(f"ALTER TABLE audit_logs {stmt}")
        # 索引幂等创建（CREATE INDEX IF NOT EXISTS 保证安全）
        conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_level ON audit_logs(level)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_logs(resource_type, resource_id)")

        # ---------- 8) scheduler_jobs 定时任务表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS scheduler_jobs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              job_id TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              func TEXT NOT NULL,
              args TEXT,
              kwargs TEXT,
              trigger TEXT NOT NULL,
              trigger_args TEXT NOT NULL,
              next_run_time TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              last_run_at TEXT,
              last_result TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(scheduler_jobs)").fetchall()}
        for col_def in [
            ("job_id", "TEXT NOT NULL DEFAULT 'unknown'"), ("name", "TEXT NOT NULL DEFAULT 'untitled'"),
            ("func", "TEXT NOT NULL DEFAULT 'noop'"), ("args", "TEXT"), ("kwargs", "TEXT"),
            ("trigger", "TEXT NOT NULL DEFAULT 'cron'"), ("trigger_args", "TEXT NOT NULL DEFAULT '{}'"),
            ("next_run_time", "TEXT"), ("status", "TEXT NOT NULL DEFAULT 'active'"),
            ("last_run_at", "TEXT"), ("last_result", "TEXT"),
            ("created_at", "TEXT"),
            ("updated_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE scheduler_jobs ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_scheduler_job_id ON scheduler_jobs(job_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_scheduler_status ON scheduler_jobs(status)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_scheduler_next_run ON scheduler_jobs(next_run_time)")

        # ---------- 9.5) feedbacks 工单表：幂等补列（SCHEMA_SQL 已定义表本身） ----------
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(feedbacks)").fetchall()}
        for col_def in [
            ("user_id", "INTEGER NOT NULL DEFAULT 0"), ("type", "TEXT NOT NULL DEFAULT 'consult'"),
            ("priority", "TEXT NOT NULL DEFAULT 'normal'"), ("title", "TEXT NOT NULL DEFAULT ''"),
            ("content", "TEXT NOT NULL DEFAULT ''"), ("ref_id", "TEXT"),
            ("status", "TEXT NOT NULL DEFAULT 'open'"), ("unread", "INTEGER NOT NULL DEFAULT 0"),
            ("created_at", "TEXT"),
            ("updated_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE feedbacks ADD COLUMN {col_def[0]} {col_def[1]}")

        # ---------- 9) feedback_replies 工单回复表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS feedback_replies (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              feedback_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              username TEXT,
              role TEXT NOT NULL DEFAULT 'user',
              content TEXT NOT NULL,
              attachments TEXT,
              is_internal INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (feedback_id) REFERENCES feedbacks(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(feedback_replies)").fetchall()}
        for col_def in [
            ("feedback_id", "INTEGER NOT NULL DEFAULT 0"), ("user_id", "INTEGER NOT NULL DEFAULT 0"),
            ("username", "TEXT"), ("role", "TEXT NOT NULL DEFAULT 'user'"),
            ("content", "TEXT NOT NULL DEFAULT ''"), ("attachments", "TEXT"),
            ("is_internal", "INTEGER NOT NULL DEFAULT 0"),
            ("created_at", "TEXT"),
            ("updated_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE feedback_replies ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_feedback_reply_fid ON feedback_replies(feedback_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_feedback_reply_uid ON feedback_replies(user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_feedback_reply_created ON feedback_replies(created_at)")

        # ---------- 10) notifications 通知中心表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              type TEXT NOT NULL DEFAULT 'system',
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              level TEXT NOT NULL DEFAULT 'info',
              resource_type TEXT,
              resource_id TEXT,
              is_read INTEGER NOT NULL DEFAULT 0,
              read_at TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(notifications)").fetchall()}
        for col_def in [
            ("user_id", "INTEGER NOT NULL DEFAULT 0"), ("type", "TEXT NOT NULL DEFAULT 'system'"),
            ("title", "TEXT NOT NULL DEFAULT ''"), ("content", "TEXT NOT NULL DEFAULT ''"),
            ("level", "TEXT NOT NULL DEFAULT 'info'"), ("resource_type", "TEXT"), ("resource_id", "TEXT"),
            ("is_read", "INTEGER NOT NULL DEFAULT 0"), ("read_at", "TEXT"),
            ("created_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE notifications ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_notification_uid ON notifications(user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_notification_read ON notifications(user_id, is_read)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_notification_created ON notifications(created_at)")

        # ---------- 11) proxy_reputation_snapshots IP信誉快照表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS proxy_reputation_snapshots (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              proxy_id INTEGER,
              server_id INTEGER,
              ip TEXT NOT NULL,
              ip_ver INTEGER NOT NULL DEFAULT 4,
              country TEXT,
              asn TEXT,
              rbl_hit INTEGER DEFAULT 0,
              rbl_total INTEGER DEFAULT 0,
              abuse_score INTEGER,
              abuse_reports INTEGER,
              ipqs_score INTEGER,
              scamalytic_score INTEGER,
              spur_score INTEGER,
              composite_score INTEGER,
              conclusion TEXT,
              raw_json TEXT,
              snapshot_type TEXT NOT NULL DEFAULT 'daily',
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (proxy_id) REFERENCES proxies(id) ON DELETE SET NULL,
              FOREIGN KEY (server_id) REFERENCES vps_servers(id) ON DELETE SET NULL
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(proxy_reputation_snapshots)").fetchall()}
        for col_def in [
            ("proxy_id", "INTEGER"), ("server_id", "INTEGER"), ("ip", "TEXT NOT NULL DEFAULT '0.0.0.0'"),
            ("ip_ver", "INTEGER NOT NULL DEFAULT 4"), ("country", "TEXT"), ("asn", "TEXT"),
            ("rbl_hit", "INTEGER DEFAULT 0"), ("rbl_total", "INTEGER DEFAULT 0"),
            ("abuse_score", "INTEGER"), ("abuse_reports", "INTEGER"), ("ipqs_score", "INTEGER"),
            ("scamalytic_score", "INTEGER"), ("spur_score", "INTEGER"),
            ("composite_score", "INTEGER"), ("conclusion", "TEXT"), ("raw_json", "TEXT"),
            ("snapshot_type", "TEXT NOT NULL DEFAULT 'daily'"),
            ("created_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE proxy_reputation_snapshots ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rep_proxy ON proxy_reputation_snapshots(proxy_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rep_server ON proxy_reputation_snapshots(server_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rep_ip ON proxy_reputation_snapshots(ip)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rep_created ON proxy_reputation_snapshots(created_at)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rep_snapshot ON proxy_reputation_snapshots(snapshot_type, created_at)")

        # ---------- 12) user_relationships 账号关系表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS user_relationships (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              parent_id INTEGER NOT NULL,
              child_id INTEGER NOT NULL UNIQUE,
              relation_type TEXT NOT NULL DEFAULT 'subaccount',
              permissions TEXT,
              max_balance REAL,
              current_balance REAL NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY (child_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(user_relationships)").fetchall()}
        for col_def in [
            ("parent_id", "INTEGER NOT NULL DEFAULT 0"), ("child_id", "INTEGER NOT NULL DEFAULT 0"),
            ("relation_type", "TEXT NOT NULL DEFAULT 'subaccount'"), ("permissions", "TEXT"),
            ("max_balance", "REAL"), ("current_balance", "REAL NOT NULL DEFAULT 0"),
            ("status", "TEXT NOT NULL DEFAULT 'active'"),
            ("created_at", "TEXT"),
            ("updated_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE user_relationships ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ur_parent ON user_relationships(parent_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ur_child ON user_relationships(child_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ur_status ON user_relationships(status)")

        # ---------- 13) coupons 优惠券表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS coupons (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'percent',
              value REAL NOT NULL,
              min_order REAL NOT NULL DEFAULT 0,
              max_discount REAL,
              usage_limit INTEGER,
              usage_count INTEGER NOT NULL DEFAULT 0,
              applies_to TEXT,
              user_scope TEXT NOT NULL DEFAULT 'all',
              valid_from TEXT,
              valid_until TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              created_by INTEGER,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(coupons)").fetchall()}
        for col_def in [
            ("code", "TEXT NOT NULL DEFAULT 'UNKNOWN'"), ("name", "TEXT NOT NULL DEFAULT '未命名优惠券'"),
            ("type", "TEXT NOT NULL DEFAULT 'percent'"), ("value", "REAL NOT NULL DEFAULT 0"),
            ("min_order", "REAL NOT NULL DEFAULT 0"), ("max_discount", "REAL"),
            ("usage_limit", "INTEGER"), ("usage_count", "INTEGER NOT NULL DEFAULT 0"),
            ("applies_to", "TEXT"), ("user_scope", "TEXT NOT NULL DEFAULT 'all'"),
            ("valid_from", "TEXT"), ("valid_until", "TEXT"), ("status", "TEXT NOT NULL DEFAULT 'active'"),
            ("created_by", "INTEGER"),
            ("created_at", "TEXT"),
            ("updated_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE coupons ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_coupon_code ON coupons(code)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_coupon_status ON coupons(status)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_coupon_valid ON coupons(valid_from, valid_until)")

        # ---------- 14) coupon_redemptions 优惠券兑换表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS coupon_redemptions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              coupon_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              order_id INTEGER,
              code TEXT NOT NULL,
              discount_amount REAL NOT NULL,
              original_amount REAL,
              final_amount REAL,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(coupon_redemptions)").fetchall()}
        for col_def in [
            ("coupon_id", "INTEGER NOT NULL DEFAULT 0"), ("user_id", "INTEGER NOT NULL DEFAULT 0"),
            ("order_id", "INTEGER"), ("code", "TEXT NOT NULL DEFAULT ''"),
            ("discount_amount", "REAL NOT NULL DEFAULT 0"), ("original_amount", "REAL"), ("final_amount", "REAL"),
            ("created_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE coupon_redemptions ADD COLUMN {col_def[0]} {col_def[1]}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_redemption_coupon ON coupon_redemptions(coupon_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_redemption_user ON coupon_redemptions(user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_redemption_order ON coupon_redemptions(order_id)")

        # ---------- 15) transfers 资金划转表：幂等建表 + 补列 ----------
        conn.execute("""
            CREATE TABLE IF NOT EXISTS transfers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              transfer_no TEXT NOT NULL UNIQUE,
              from_user_id INTEGER NOT NULL,
              to_user_id INTEGER NOT NULL,
              from_username TEXT,
              to_username TEXT,
              currency TEXT NOT NULL DEFAULT 'CNY',
              amount REAL NOT NULL,
              fee REAL NOT NULL DEFAULT 0,
              type TEXT NOT NULL DEFAULT 'parent_to_child',
              remark TEXT,
              status TEXT NOT NULL DEFAULT 'completed',
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
              FOREIGN KEY (from_user_id) REFERENCES users(id),
              FOREIGN KEY (to_user_id) REFERENCES users(id)
            )
        """)
        cur_cols = {r["name"] for r in conn.execute("PRAGMA table_info(transfers)").fetchall()}
        for col_def in [
            ("transfer_no", "TEXT NOT NULL DEFAULT 'TR0'"), ("from_user_id", "INTEGER NOT NULL DEFAULT 0"),
            ("to_user_id", "INTEGER NOT NULL DEFAULT 0"),
            ("from_username", "TEXT"), ("to_username", "TEXT"),
            ("currency", "TEXT NOT NULL DEFAULT 'CNY'"),
            ("amount", "REAL NOT NULL DEFAULT 0"),
            ("fee", "REAL NOT NULL DEFAULT 0"), ("type", "TEXT NOT NULL DEFAULT 'parent_to_child'"),
            ("remark", "TEXT"), ("status", "TEXT NOT NULL DEFAULT 'completed'"),
            ("created_at", "TEXT"),
        ]:
            if col_def[0] not in cur_cols:
                conn.execute(f"ALTER TABLE transfers ADD COLUMN {col_def[0]} {col_def[1]}")
        # 回填历史 from_username/to_username（存在时才执行）
        try:
            conn.execute("""
                UPDATE transfers SET from_username = (
                    SELECT u.username FROM users u WHERE u.id = transfers.from_user_id
                ) WHERE from_username IS NULL OR from_username = ''
            """)
            conn.execute("""
                UPDATE transfers SET to_username = (
                    SELECT u.username FROM users u WHERE u.id = transfers.to_user_id
                ) WHERE to_username IS NULL OR to_username = ''
            """)
        except Exception:
            pass
        conn.execute("CREATE INDEX IF NOT EXISTS idx_transfer_from ON transfers(from_user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_transfer_to ON transfers(to_user_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_transfer_status ON transfers(status)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_transfer_created ON transfers(created_at)")

        # ---------- 16) 补充权限码：交易、优惠券、划转、通知、子账号、定时任务等 ----------
        extra_perms = [
            ("transactions:view", "查看交易流水", "钱包账单"),
            ("wallet:transfer", "资金划转", "钱包账单"),
            ("wallet:recharge", "创建充值订单", "钱包账单"),
            ("subaccounts:view", "查看子账号", "账号管理"),
            ("subaccounts:manage", "管理子账号", "账号管理"),
            ("coupons:view", "查看优惠券", "优惠券"),
            ("coupons:manage", "管理优惠券", "优惠券"),
            ("coupons:redeem", "兑换优惠券", "优惠券"),
            ("notifications:view", "查看通知", "通知中心"),
            ("feedback:reply", "回复工单", "反馈"),
            ("reputation:view", "查看IP信誉快照", "网络检测中心"),
            ("scheduler:view", "查看定时任务", "系统"),
            ("scheduler:manage", "管理定时任务", "系统"),
        ]
        conn.executemany(
            "INSERT OR IGNORE INTO permissions (code, name, group_name) VALUES (?,?,?)",
            extra_perms,
        )
        # super_admin + admin 自动获得新增权限
        all_new_codes = [p[0] for p in extra_perms]
        for role_code in ["super_admin", "admin"]:
            conn.executemany(
                "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
                [(role_code, c) for c in all_new_codes],
            )
        # finance: 交易、充值、优惠券
        finance_extra = ["transactions:view", "wallet:recharge", "coupons:view", "wallet:transfer"]
        conn.executemany(
            "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
            [("finance", c) for c in finance_extra],
        )
        # user: 查看交易、划转、充值、自己的通知、自己的子账号、兑换优惠券、查看IP信誉
        user_extra = ["transactions:view", "wallet:transfer", "wallet:recharge",
                      "notifications:view", "coupons:redeem", "reputation:view",
                      "subaccounts:view", "feedback:reply"]
        conn.executemany(
            "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
            [("user", c) for c in user_extra],
        )
        # support: 工单回复、通知、IP信誉、子账号查看
        support_extra = ["feedback:reply", "notifications:view", "reputation:view",
                         "subaccounts:view", "transactions:view"]
        conn.executemany(
            "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
            [("support", c) for c in support_extra],
        )
