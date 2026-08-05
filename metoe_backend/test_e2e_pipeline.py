"""端到端流程测试：注册/登录 → 下单 → 余额支付 → Lisa主机API下单 → VPN部署 → 交付二维码/链接"""
import requests, time, json

BASE = "http://localhost:3000"

def s():
    print("=" * 80)

print("\n" + "="*80)
print("TEST: 用户登录 demo/123456")
s()
r = requests.post(f"{BASE}/api/auth/login", json={"username": "demo", "password": "123456"})
print("login status:", r.status_code)
data = r.json()
print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])
assert data["code"] == 200, f"登录失败: {data}"
tok = data["data"]["token"]
H = {"Authorization": f"Bearer {tok}"}

print("\n" + "="*80)
print("TEST: 获取客服信息（公开接口）")
s()
r = requests.get(f"{BASE}/api/config/customer-service")
print("cs info:", r.status_code, json.dumps(r.json(), ensure_ascii=False, indent=2)[:1200])
assert r.json()["code"] == 200

print("\n" + "="*80)
print("TEST: 购买代理：选择 US ISP standard 套餐 1 IP 1个月")
s()
buy = {
  "category": "ISP",
  "country": "US",
  "countryName": "美国",
  "countryFlag": "🇺🇸",
  "qty": 1,
  "period": "1m",
  "plan": "standard",
  "amount": 149.0,
  "discount": 0,
  "total": 149.0,
  "protocols": ["HTTP","SOCKS5"],
  "auth": "pwd",
}
r = requests.post(f"{BASE}/api/proxies/buy", json=buy, headers=H)
print("buy:", r.status_code)
buy_res = r.json()
print(json.dumps(buy_res, ensure_ascii=False, indent=2)[:2000])
assert buy_res["code"] == 200
order_no = buy_res["data"]["orderNo"]
order_id = buy_res["data"]["orderId"]
print("创建订单成功：orderNo =", order_no, "orderId =", order_id)
assert buy_res["data"]["needPay"] == True

print("\n" + "="*80)
print("TEST: 查询订单详情（pending 状态）")
s()
r = requests.get(f"{BASE}/api/orders/{order_no}", headers=H)
dt = r.json()
print("status:", r.status_code, dt["data"].get("status"), dt["data"].get("deployStatus"))
assert dt["data"]["status"] == "pending"

print("\n" + "="*80)
print("TEST: 余额支付 (channel=balance)")
s()
r = requests.post(f"{BASE}/api/orders/{order_no}/pay", json={"channel": "balance"}, headers=H)
pay_res = r.json()
print("pay:", r.status_code)
print(json.dumps(pay_res, ensure_ascii=False, indent=2)[:3000])
assert pay_res["code"] == 200
assert pay_res["data"]["paid"] is True
deploy_id = pay_res["data"].get("deploy_id")
vps_ip = pay_res["data"].get("vps_ip")
print(f"支付成功 → deploy_id={deploy_id}, vps_ip={vps_ip}")

print("\n" + "="*80)
print("TEST: 轮询订单详情，等待部署完成（最多80秒，模拟任务每10秒有进度）")
s()
finished = False
for i in range(20):
    time.sleep(4)
    r = requests.get(f"{BASE}/api/orders/{order_no}", headers=H)
    od = r.json()["data"]
    ds = od.get("deploy", {}).get("status") or od.get("deployStatus")
    prog = od.get("deploy", {}).get("progress") or 0
    proxies = od.get("proxies") or []
    print(f"  [{(i+1)*4:3d}s] deploy_status={ds or '-':8s}  progress={prog:3d}%  proxies_count={len(proxies)}  vpn_url={proxies[0].get('vpn_url') if proxies else '-'}")
    if ds == "done" and proxies and proxies[0].get("vpn_url"):
        finished = True
        print("  ✓ 部署完成！VPN 链接已生成。")
        p = proxies[0]
        print("  连接信息：", p["ip"], ":", p["port"], " user=", p["username"], " pwd=", p["password"])
        print("  vpn_url=", p["vpn_url"])
        print("  vpn_qr_code=", p.get("vpn_qr_code"))
        print("  vpn_config_path=", p.get("vpn_config_path"))
        print("  config snippet:")
        for line in (p.get("vpn_config_content") or "").split("\n")[:6]: print("   ", line)
        print("  server_ip=", od.get("server", {}).get("ip"),
              "  ssh_pwd=", od.get("server", {}).get("ssh_password"))
        break
assert finished, "部署未在超时前完成"

print("\n" + "="*80)
print("TEST: 查询代理列表，确认VPN交付字段存在 (vpnUrl, vpnQrCode, vpnConfigPath)")
s()
r = requests.get(f"{BASE}/api/proxies?page=1&pageSize=3", headers=H)
pl = r.json()["data"]
print("total:", pl["total"])
for p in pl["list"][:3]:
    print(f"  [{p['id']}] {p['countryFlag']}{p['country']} IP={p['ip']}:{p['port']} status={p['status']} vpnUrl={p.get('vpnUrl')}")
    print(f"       vpnQrCode={p.get('vpnQrCode')}  vpnConfigPath={p.get('vpnConfigPath')}")
    if p.get("vpnUrl"):
        break

print("\n" + "="*80)
print("TEST: 查询VPS服务器列表")
s()
r = requests.get(f"{BASE}/api/servers", headers=H)
sl = r.json()["data"]
print("servers total:", sl["total"])
for sv in sl["list"][:3]:
    print(f"  [{sv['id']}] {sv['ip']} {sv['provider']}/{sv['region']} {sv['cpuCores']}核/{sv['ramMb']}MB status={sv['status']}")

print("\n" + "="*80)
print("TEST: 模拟支付（mock 渠道） + 手动回调确认")
s()
# 再下一单，这次用 mock 支付
buy2 = {**buy, "amount": 89, "total": 89, "plan": "basic", "period": "1m", "country": "JP",
        "countryName": "日本", "countryFlag": "🇯🇵"}
r = requests.post(f"{BASE}/api/proxies/buy", json=buy2, headers=H)
b2 = r.json()
assert b2["code"] == 200
order2 = b2["data"]["orderNo"]
print("  mock 订单号:", order2)
r = requests.post(f"{BASE}/api/orders/{order2}/pay", json={"channel": "mock"}, headers=H)
pr = r.json()
print("  mock pay:", pr["code"], pr["data"].get("paid"), pr["data"].get("qr_data")[:50])
assert pr["data"]["paid"] is False
pay_no = pr["data"]["pay_no"]
# 模拟支付回调
r = requests.get(f"{BASE}/api/payments/mock-confirm?pay_no={pay_no}")
cf = r.json()
print("  mock confirm:", cf["code"], cf["message"])
time.sleep(5)
r = requests.get(f"{BASE}/api/orders/{order2}", headers=H)
od2 = r.json()["data"]
print("  confirm后订单状态:", od2.get("status"), "  proxies:", len(od2.get("proxies", [])))
assert od2.get("status") == "paid", "mock支付后应变为paid"

print("\n" + "="*80)
print("全部业务流程测试通过！ ✓")
print("=" * 80)
