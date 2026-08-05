"""Shorter end-to-end: balance+paypal+usdt pipelines"""
import requests, json, time, sys
BASE = 'http://localhost:3000'

def step(n, title):
    print('\n' + '='*80); print(f'{n}. {title}')

# 1. login
step(1, '登录 demo / 123456')
r = requests.post(f'{BASE}/auth/login', json={'username':'demo','password':'123456'})
d = r.json()['data']; tok = d['token']
print(f"login ok user={d['user']['username']} balance={d['user']['balance']}")
H = {'Authorization': f'Bearer {tok}'}

# 2. payment channels
step(2, '支付渠道开关检查')
r = requests.get(f'{BASE}/config/payment-channels'); chs = r.json()['data']
print('  channels:', [(c['key'], c.get('enabled')) for c in chs])
usdt = next(c for c in chs if c['key']=='usdt')
pp = next(c for c in chs if c['key']=='paypal')
print(f"  usdt: net={usdt['wallet']['network']} addr={usdt['wallet']['address'][:12]}... rate=1USD={usdt['rate']['cny_per_usd']}CNY")
print(f"  paypal: mode={pp['paypal']['mode']} clientId={pp['paypal']['client_id'][:12]}... currency={pp['currency']} fee_rate={pp['paypal']['fee_rate']}")

def try_balance_pay():
    step(3, '[余额支付] 创建订单并支付')
    buy = {
      'category':'ISP','country':'US','countryName':'美国','countryFlag':'🇺🇸',
      'qty':1,'period':'1m','plan':'standard','amount':149.0,'discount':0,'total':149.0,
      'protocols':['HTTP','SOCKS5'],'auth':'pwd','city':'Los Angeles','isp_name':'Comcast',
    }
    r = requests.post(f'{BASE}/proxies/buy', json=buy, headers=H); print('  buy status:', r.status_code)
    d = r.json(); print(d['message']); print('  code=', d.get('code'))
    ono = d['data']['orderNo']
    print(f'  orderNo={ono}')
    r = requests.post(f'{BASE}/orders/{ono}/pay', json={'channel':'balance'}, headers=H)
    print('  pay status:', r.status_code);
    p = r.json(); print(f"  pay msg: {p['message']}"); print(f"  pay data keys: {list(p.get('data',{}).keys()) if p.get('data') else p.get('data')}")
    paid = (p.get('data') or {}).get('paid')
    depid = (p.get('data') or {}).get('deploy_id')
    print(f'  paid={paid}  deploy_id={depid}')
    return paid, depid, ono

paid, depid, ono_balance = try_balance_pay()
if not paid:
    print('FAILED balance pay. STOP.'); sys.exit(1)

# wait deployment
step(4, '等待部署完成并验证VPN交付')
for i in range(20):
    r = requests.get(f'{BASE}/deploy-tasks/{depid}', headers=H); d = r.json().get('data', {})
    st = d.get('status_text') or d.get('status') or '?'; prog = d.get('progress')
    print(f'  [{i+1}/20] deploy {depid}: status={st} progress={prog}% phase={d.get("current_phase")}')
    if d.get('status_code') == 3 or str(st).lower() in ('done','success','successful','completed'):
        print('  DEPLOY SUCCESS'); break
    time.sleep(2)

# show delivered VPN
step(5, '查看最终交付')
r = requests.get(f'{BASE}/servers/mine', headers=H); srvs = r.json().get('data', {}).get('list') or []
print(f'  我的VPS数: {len(srvs)}')
if srvs:
    s = srvs[-1]; print(f"  最近VPS id={s.get('id')} ip={s.get('ip')} status={s.get('status')}")
r = requests.get(f'{BASE}/proxies/mine', headers=H); prs = r.json().get('data', {}).get('list') or []
print(f'  我的代理数: {len(prs)}')
if prs:
    p = prs[-1]
    print(f"  最近代理 id={p.get('id')} ip={p.get('ip')}:{p.get('port')} status={p.get('status')}")
    if p.get('qr_url') or p.get('share_url'):
        print(f"    qr={p.get('qr_url')} share={p.get('share_url')}")

# ---- PayPal pipeline ----
step(6, '[PayPal 官方 v2 Orders API] 创建订单 → 捕获 → 部署')
buy2 = {
  'category':'DCH','country':'JP','countryName':'日本','countryFlag':'🇯🇵',
  'qty':1,'period':'1m','plan':'pro','amount':458.0,'discount':0,'total':458.0,
  'protocols':['HTTP','SOCKS5'],'auth':'pwd',
}
r = requests.post(f'{BASE}/proxies/buy', json=buy2, headers=H); ono2 = r.json()['data']['orderNo']
print(f'  orderNo={ono2}')

# 6a. call backend create payment (paypal) → returns paypal order
r = requests.post(f'{BASE}/orders/{ono2}/pay', json={'channel':'paypal'}, headers=H)
print('  pay/paypal status:', r.status_code); pp_data = r.json()['data']
pp_order_id = pp_data['paypal']['order_id']
print(f"  paypal order id={pp_order_id} paid={pp_data.get('paid')}")
print(f"  approval_url={pp_data['paypal']['approval_url'][:80]}...")
print(f"  settle: amount={pp_data['settle']['amount']}{pp_data['settle']['currency']} fee=${pp_data['settle']['fee_usd']}")

# 6b. 模拟官方 PayPal API: 先 GET 查看订单
r = requests.get(f'{BASE}/payments/paypal/v2/orders/{pp_order_id}')
print(f'  [PayPal GET v2/orders] status code={r.status_code} body.status={r.json().get("status")}')

# 6c. Capture（模拟前端 approve 后调用 capture）
r = requests.post(f'{BASE}/payments/paypal/v2/orders/{pp_order_id}/capture')
print(f'  [PayPal CAPTURE v2] status code={r.status_code}'); cap = r.json()
print(f"    capture status={cap.get('status')} payer_given={cap.get('payer',{}).get('name',{}).get('given_name')}")
pay_no = None
for pu in cap.get('purchase_units', []):
    for pm in pu.get('payments', {}).get('captures', []):
        pp_capture_id = pm['id']; print(f'    capture_id={pp_capture_id} status={pm.get("status")}')
        sf = pm.get('seller_protection',{}); print(f'    seller protection: {sf.get("status") if sf else None}')
        cus = pm.get('custom_id') or (pu or {}).get('custom_id'); pay_no = cus
        if cus: print(f'    custom_id(pay_no)={cus}')
print(f"    → 后端回调 pay_no={pay_no}")

# 6d. 确认订单已部署
r = requests.get(f'{BASE}/orders/{ono2}', headers=H); od = r.json()['data']
print(f"  订单 status={od['status']} deploy_task_id={od.get('deploy_task_id')} paidAt={od.get('paid_at')}")

# ---- USDT pipeline ----
step(7, '[USDT TRC20 链上支付] 创建订单 → 前端展示钱包→ 模拟链上到账回调 → 部署')
buy3 = {
  'category':'DCH','country':'GB','countryName':'英国','countryFlag':'🇬🇧',
  'qty':1,'period':'3m','plan':'standard','amount':199.0,'discount':0,'total':597.0,
  'protocols':['HTTP','SOCKS5'],'auth':'pwd',
}
r = requests.post(f'{BASE}/proxies/buy', json=buy3, headers=H); ono3 = r.json()['data']['orderNo']
print(f'  orderNo={ono3}')

r = requests.post(f'{BASE}/orders/{ono3}/pay', json={'channel':'usdt'}, headers=H); ud = r.json()['data']
print(f"  pay/usdt pay_no={ud['pay_no']} amount_cny={ud['amount_cny']} amount_usdt={ud['amount_usdt']}")
print(f"  wallet addr={ud['wallet']['address']} net={ud['wallet']['network']} unique_amount={ud['amount_usdt']} USDT")
print(f"  qr_data={ud['qr_data'][:60]}... expire={ud['expire_at']}")

# chain callback (模拟扫描到账)
notify_body = {
    "network": ud['wallet']['network'],
    "txid": "0x" + "".join(hex(x)[2:] for x in [11,22,33,44,55,66,77,88]).ljust(64,'0') + "aabb",
    "block_number": 68523411,
    "block_time": int(time.time()),
    "from_address": "TFromAddressxxxxxxxxxxxxxxxxxx",
    "to_address": ud['wallet']['address'],
    "contract_address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
    "coin": "USDT",
    "amount": float(ud['amount_usdt']),
    "confirmations": 3,
}
r = requests.post(f'{BASE}/payments/usdt/notify', json=notify_body)
nresp = r.json(); print(f"  usdt/notify code={nresp.get('code')} msg={nresp.get('message')}")
nd = nresp.get('data') or {}
print(f"    matched pay_no={nd.get('pay_no')} paid={nd.get('paid')} order_no={nd.get('order_no')}")

# verify order deployed
r = requests.get(f'{BASE}/orders/{ono3}', headers=H); od3 = r.json()['data']
print(f"  订单 {ono3} status={od3['status']} deploy_task_id={od3.get('deploy_task_id')}")

step(8, '检查所有订单状态')
r = requests.get(f'{BASE}/orders/mine', headers=H); ol = r.json()['data']['list']
for o in ol[-5:]:
    print(f"  {o['order_no']} status={o['status']:7s} pay={o.get('pay_method') or '-':8s} total={o.get('total')}")

print('\nALL PASSED' if paid and depid else 'HAD FAILURES')
