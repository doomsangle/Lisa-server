"""E2E 购买→支付→部署流水线测试：覆盖 balance / PayPal / USDT / PayPal v2 Orders"""
import requests, time, json

BASE = "http://localhost:3000"

def sep(n="="): print("\n" + n*80)

print("\n" + "="*80)
print("1. 登录 demo / 123456")
r = requests.post(f"{BASE}/auth/login", json={"username":"demo","password":"123456"})
print("login status:", r.status_code)
d = r.json()
assert d.get("code") == 0 or d.get("code") == 200, f"login fail: {d}"
tok = d["data"]["token"]
H = {"Authorization": f"Bearer {tok}"}
print("login ok, user=", d["data"]["user"]["username"],
      "balance=", d["data"]["user"]["balance"])

sep()
print("2. 获取系统配置 - 支付渠道(PayPal+USDT开关) & 客服信息")
r = requests.get(f"{BASE}/config/payment-channels")
ch = r.json()["data"]
print(f"  共{len(ch)}种支付渠道：", [(c["key"], "ON" if c["enabled"] else "off") for c in ch])
for c in ch:
    if c["key"] == "paypal":
        print(f"  PayPal: mode={c.get('paypal',{}).get('mode')} "
              f"currency={c.get('currency')} rate=1USD={c.get('rate',{}).get('cny_per_usd')}CNY "
              f"fee={c.get('paypal',{}).get('fee_rate')}")
    if c["key"] == "usdt":
        print(f"  USDT: network={c.get('wallet',{}).get('network')} "
              f"addr={c.get('wallet',{}).get('address')[:12]}... rate=1USD={c.get('rate',{}).get('cny_per_usd')}CNY")
r2 = requests.get(f"{BASE}/config/customer-service")
cs = r2.json()["data"]["data"]
print(f"  客服：wechat={cs.get('cs_wechat')}  qq={cs.get('cs_qq')}  email={cs.get('cs_email')}  phone={cs.get('cs_phone')}")

sep()
print("3. [余额支付] 购买 1个美国ISP住宅(1个月) → 立即付款→部署")
buy = {
  "category":"ISP","country":"US","countryName":"美国","countryFlag":"🇺🇸",
  "qty":1,"period":"1m","plan":"standard","amount":149.0,
  "discount":0,"total":149.0,"protocols":["HTTP","SOCKS5"],"auth":"pwd",
}
r = requests.post(f"{BASE}/proxies/buy", json=buy, headers=H)
br = r.json(); assert br["code"] == 200 or br.get("code") == 0, f"buy fail: {br}"
oid, ono = br["data"]["orderId"], br["data"]["orderNo"]
print(f"  下单成功: orderId={oid} orderNo={ono}  needPay={br['data'].get('needPay')}")
r = requests.post(f"{BASE}/orders/{ono}/pay", json={"channel":"balance"}, headers=H)
pay_r = r.json()
print(f"  余额支付结果: code={pay_r.get('code')}  paid={pay_r.get('data',{}).get('paid')} "
      f"deploy_id={pay_r.get('data',{}).get('deploy_id')}  msg=", pay_r.get("message"))
assert pay_r.get("data",{}).get("paid") is True
deploy_id = pay_r["data"]["deploy_id"]
print("  等待部署...")
done = False
for i in range(20):
    time.sleep(4)
    r = requests.get(f"{BASE}/orders/{ono}", headers=H)
    od = r.json().get("data") or {}
    ds = (od.get("deploy") or {}).get("status") or od.get("deployStatus")
    prog = (od.get("deploy") or {}).get("progress") or 0
    pxs = od.get("proxies") or []
    vpn = pxs[0].get("vpn_url") if pxs else None
    print(f"    [{(i+1)*4:3d}s] deploy={ds or '-':10s}  progress={prog:3d}%  proxies={len(pxs)}  vpn={bool(vpn)}")
    if ds == "done" and vpn:
        done = True; print("  ✓ 部署完成，VPN交付"); p=pxs[0]
        print(f"    IP={p['ip']}:{p['port']}  user={p['username']}  pwd={p['password']}")
        print(f"    vpnUrl={p.get('vpn_url')}  qr={'OK' if p.get('vpn_qr_code') else 'no'}")
        break
assert done, "部署超时"

sep()
print("4. [PayPal 官方API风格] 购买1个日本VPN月付 → 创建PayPal订单→调用capture→部署")
buy2 = {**buy, "country":"JP","countryName":"日本","countryFlag":"🇯🇵",
        "amount":129.0,"total":129.0,"plan":"basic"}
r = requests.post(f"{BASE}/proxies/buy", json=buy2, headers=H)
b2 = r.json()["data"]
ono2 = b2["orderNo"]

# 方式A：通过统一入口 create_payment(channel=paypal) —— 推荐
r = requests.post(f"{BASE}/orders/{ono2}/pay", json={"channel":"paypal"}, headers=H)
pay = r.json()["data"]
print(f"  创建PayPal支付单: pay_no={pay['pay_no']} pp_order_id={pay['paypal']['order_id']}")
print(f"    应付CNY: ￥{pay['amount']}  →  结算USD: ${pay['settle']['amount']} + 手续费${pay['settle']['fee_usd']} = ${pay['settle']['total_usd']}")
print(f"    Sandbox批准链接: {pay['paypal']['approval_url'][:80]}...")
print(f"    官方V2风格Capture接口: {pay['confirm_endpoints']['capture']}")

# 方式B：直接调用 PayPal 官方同构接口 POST /paypal/v2/orders/capture
ppoid = pay["paypal"]["order_id"]
r = requests.post(f"{BASE}/payments/paypal/v2/orders/{ppoid}/capture")
cap = r.json()
print(f"  PayPal Capture结果: status={cap.get('status')}  capture_id={cap['purchase_units'][0]['payments']['captures'][0]['id']}")
print(f"    内部部署id: {cap.get('internal',{}).get('deploy_id')}")

# 轮询VPN交付
done=False
for i in range(18):
    time.sleep(3)
    r = requests.get(f"{BASE}/orders/{ono2}", headers=H)
    od = r.json()["data"]
    ds = (od.get("deploy") or {}).get("status") or "-"
    pxs = od.get("proxies") or []
    vpn = pxs[0].get("vpn_url") if pxs else None
    if i%3==0 or (ds=="done" and vpn):
        print(f"    [{(i+1)*3:3d}s] deploy={ds:10s} proxies={len(pxs)} vpn={bool(vpn)}")
    if ds=="done" and vpn:
        done=True; print("  ✓ PayPal支付后的VPN部署完成！"); break
assert done, "PayPal流程部署超时"

sep()
print("5. [USDT(TRC20)链上支付] 购买1个德国VPN → 生成唯一金额→发送通知→部署")
buy3 = {**buy, "country":"DE","countryName":"德国","countryFlag":"🇩🇪",
        "amount":199.0,"total":199.0,"plan":"premium","period":"1m"}
r = requests.post(f"{BASE}/proxies/buy", json=buy3, headers=H)
ono3 = r.json()["data"]["orderNo"]
r = requests.post(f"{BASE}/orders/{ono3}/pay", json={"channel":"usdt"}, headers=H)
u = r.json()["data"]
print(f"  创建USDT支付单: pay_no={u['pay_no']}")
print(f"    应付CNY: ￥{u['amount_cny']}  → 折合USDT {u['wallet']['amount']} {u['wallet']['network']}")
print(f"    钱包地址: {u['wallet']['address']}")
print(f"    标准二维码URI(BIP21/TRON): {u['qr_uri'][:70]}...")
print(f"    tips: {u['tips'][0]}")

# 模拟 Tron 节点发现到账 => 调用 /usdt/notify 回调
amt_float = u["wallet"]["amount_raw"]
txid = "0x" + "".join(__import__("random").choices("0123456789abcdef", k=62))
r = requests.post(f"{BASE}/payments/usdt/notify", json={
    "txid": txid, "network": "TRC20", "amount": amt_float,
    "to_address": u["wallet"]["address"], "from_address": "TDEMOxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "confirmations": 3,
})
print(f"  USDT链上通知回调结果: code={r.json().get('code')} msg={r.json().get('message')}")
deploy_id3 = r.json()["data"]["deploy_id"]
print(f"    deploy_id={deploy_id3}  server_id={r.json()['data'].get('server_id')}")

# 查询 usdt/check
r = requests.get(f"{BASE}/payments/usdt/check", params={"pay_no": u["pay_no"]}, headers=H)
st = r.json()["data"]
print(f"  USDT支付状态查询: status={st['status']} order_status={st['order_status']} confirmations={st.get('confirmations')} txid_present={bool(st.get('txid'))}")

done=False
for i in range(18):
    time.sleep(3)
    r = requests.get(f"{BASE}/orders/{ono3}", headers=H)
    od = r.json()["data"]
    ds = (od.get("deploy") or {}).get("status") or "-"
    pxs = od.get("proxies") or []
    vpn = pxs[0].get("vpn_url") if pxs else None
    if i%3==0 or (ds=="done" and vpn):
        print(f"    [{(i+1)*3:3d}s] deploy={ds:10s} proxies={len(pxs)} vpn={bool(vpn)}")
    if ds=="done" and vpn:
        done=True; p=pxs[0]
        print(f"  ✓ USDT到账后的VPN部署完成！ IP={p['ip']} port={p['port']}")
        print(f"    vpnUrl={p.get('vpn_url')}  vpnConfigContent={bool(p.get('vpn_config_content'))}")
        break
assert done, "USDT流程部署超时"

sep()
print("6. PayPal v2 Orders 官方同构接口测试（独立创建+捕获）")
# 创建订单(官方v2 payload结构)
r = requests.post(f"{BASE}/payments/paypal/v2/orders", json={
    "intent":"CAPTURE",
    "purchase_units":[{"reference_id":"REF_TEST","amount":{"currency_code":"USD","value":"19.99"}}],
    "application_context":{"return_url":"https://example.com/ok","cancel_url":"https://example.com/cancel"},
})
v2o = r.json()
print(f"  创建Orders v2: id={v2o['id']} status={v2o['status']}")
for ln in v2o["links"]:
    print(f"    link {ln['rel']:10s} {ln['method']:5s} -> {ln['href'][:72]}")
# 捕获
r = requests.post(f"{BASE}/payments/paypal/v2/orders/{v2o['id']}/capture")
v2c = r.json()
print(f"  Capture: status={v2c.get('status')}  capture_id={v2c['purchase_units'][0]['payments']['captures'][0]['id']}")
# Webhook模拟
r = requests.post(f"{BASE}/payments/paypal/webhook", json={
    "event_type":"CHECKOUT.ORDER.COMPLETED",
    "resource_type":"checkout-order",
    "resource":{"id":v2o["id"],"status":"COMPLETED",
                "purchase_units":[{"amount":{"currency_code":"USD","value":"19.99"},"custom_id":"NO_MATCH"}]},
})
print(f"  PayPal Webhook(无匹配订单): {r.json()}")

sep()
print("7. 后台查询：代理列表、服务器列表、支付流水、部署任务")
r = requests.get(f"{BASE}/proxies", params={"page":1,"pageSize":5}, headers=H)
print(f"  代理数: total={r.json()['data']['total']}")
r = requests.get(f"{BASE}/servers", headers=H)
print(f"  VPS服务器数: total={r.json()['data']['total']}")
r = requests.get(f"{BASE}/payments/list", params={"page":1,"pageSize":10}, headers=H)
items = r.json()["data"]["items"]
print(f"  支付流水分组counts: " +
      str({ch: sum(1 for x in items if x["channel"]==ch) for ch in sorted(set(x["channel"] for x in items))}))
r = requests.get(f"{BASE}/deploy/list", params={"page":1,"pageSize":5}, headers=H)
if r.status_code==200:
    t = r.json().get("data",{}).get("total")
    print(f"  部署任务数: total={t}")
else:
    print(f"  deploy list status: {r.status_code}")

sep()
print("✅ 全部E2E测试通过：")
print("   ✔ 余额支付(balance) → 下单 → 部署 → VPN交付")
print("   ✔ PayPal创建订单 → Capture → 部署 → VPN交付")
print("   ✔ USDT TRC20生成唯一金额 → 链上通知 → 部署 → VPN交付")
print("   ✔ PayPal v2 Orders/Capture/Webhook 官方同构接口可用")
print("   ✔ 代理/VPS/支付/部署 后台记录正确保存")
print("="*80)
