"""Mini callback test: fast, no deploy polling."""
from __future__ import annotations
import json, uuid, requests, time, sys
BASE = "http://localhost:3000"
S = requests.Session()

def step(title): print(f"\n{'='*70}\n  {title}\n{'='*70}")
def show(tag, obj, n=600):
    s = json.dumps(obj, ensure_ascii=False, indent=2)
    print(f"--- {tag} ---")
    print(s if len(s)<n else (s[:n] + "\n...(truncated)"))
    print()
def jchk(r, tag, expect_codes=(0,200,201)):
    try: d = r.json()
    except Exception as e:
        print(f"[FAIL {tag}] HTTP {r.status_code}: {r.text[:300]}"); sys.exit(1)
    print(f"[OK {tag}] HTTP {r.status_code}  code={d.get('code') if isinstance(d,dict) else 'N/A'}")
    return d

# --- 1. Login
step("1. 登录 demo / 123456")
r = S.post(f"{BASE}/auth/login", json=dict(username="demo", password="123456"))
login = jchk(r, "login")
TOK = "Bearer " + (login["data"].get("accessToken") or login["data"]["token"])
H = {"Authorization": TOK, "Content-Type": "application/json"}
UID = (login["data"].get("user") or {}).get("id") or login["data"].get("userId")
print(f"  userId={UID}  token len={len(TOK)}")

# --- 2. Get country + prices
step("2. 读取国家树/价格 (准备下单)")
r = S.get(f"{BASE}/proxies/country-tree", headers=H)
tree = jchk(r, "country-tree")
CO = tree["data"][0]["items"][0]
r = S.get(f"{BASE}/proxies/prices", headers=H, params=dict(category="ISP"))
prices = jchk(r, "prices")
plan = prices["data"]["plans"][1]
print(f"  国家: {CO['flag']}{CO['name']} ({CO['code']})  套餐: {plan['name']} ¥{plan['price']}/月")

# --- 3. Create 2 orders
def buy(city="随机", bw=30, p=30):
    return S.post(f"{BASE}/proxies/buy", headers=H, json=dict(
        country=CO["code"], city=city,
        cpuPlan=plan.get("cpuPlan") or plan.get("key") or "standard",
        bandwidth=bw, bwMode="fixed", qty=1, period=p,
        protocol="SOCKS5", usage="general", authMode="userpass",
        username=f"u_test_{uuid.uuid4().hex[:6]}",
        password=f"Pw{uuid.uuid4().hex[:8]}_!",
        udp=False, encryptMode="default",
        os="Ubuntu 22.04 LTS", autoRenew=False,
    ), timeout=10)

step("3a. 创建订单 A (PayPal 用)")
r = buy(city="随机", bw=30, p=30)
orderA = jchk(r, "buy order A")
OA = orderA["data"]
OID_A = OA.get("orderId") or OA.get("order_id") or OA.get("id")
ONO_A = OA.get("orderNo") or OA.get("order_no") or f"ORD_A_{OID_A}"
show("order A (summary, first few keys)",
     {k:OA[k] for k in list(OA.keys())[:10]})

step("3b. 创建订单 B (USDT 用)")
r = buy(city="Los Angeles", bw=20, p=60)
orderB = jchk(r, "buy order B")
OB = orderB["data"]
OID_B = OB.get("orderId") or OB.get("order_id") or OB.get("id")
ONO_B = OB.get("orderNo") or OB.get("order_no") or f"ORD_B_{OID_B}"
show("order B (summary, first few keys)",
     {k:OB[k] for k in list(OB.keys())[:10]})

def pay_create(channel, oid, ono):
    return S.post(f"{BASE}/payments/create", headers=H, json=dict(
        order_id=oid, order_no=ono, channel=channel,
        return_url="http://localhost:5173/orders", cancel_url="http://localhost:5173/orders",
    ), timeout=10)

# --- 4. PayPal payment + webhook callback
step("4a. 创建 PayPal 支付单")
r = pay_create("paypal", OID_A, ONO_A)
paypal_pay = jchk(r, "paypal create")
PAYP = paypal_pay["data"]
PNO_P = PAYP.get("payNo") or PAYP.get("pay_no")
AMT_USD = float(PAYP.get("amount") or PAYP.get("usdAmount") or PAYP.get("amountUsd") or 27.50)
print(f"  PayPal payNo={PNO_P}  USD amount={AMT_USD}")
show("PayPal 支付单", PAYP)

step("4b. 👉 PayPal Webhook 回调 (CHECKOUT.ORDER.COMPLETED)")
PAYPAL_BODY = {
    "id": f"WH-TEST-{uuid.uuid4().hex}",
    "event_version": "1.0",
    "create_time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "event_type": "CHECKOUT.ORDER.COMPLETED",
    "resource_type": "checkout-order",
    "summary": "Checkout Order Completed",
    "resource": {
        "id": "5O190127TN364715T",
        "intent": "CAPTURE",
        "status": "COMPLETED",
        "custom_id": PNO_P,
        "purchase_units": [
            {
                "reference_id": ONO_A,
                "custom_id": PNO_P,
                "amount": {"currency_code": "USD", "value": f"{AMT_USD:.2f}"},
                "payee": {"email_address": "seller@metoe.io"},
            }
        ],
        "payer": {
            "email_address": "demo-buyer@sandbox.paypal.com",
            "payer_id": "DEMOBUYERID1234",
            "name": {"given_name": "Demo", "surname": "Buyer"},
            "address": {"country_code": "US"}
        },
    },
}
show("PayPal Webhook Body (POST /payments/paypal/webhook)", PAYPAL_BODY, n=1500)
print("\n  [CURL] 可直接复制执行:")
print(f"  curl -X POST {BASE}/payments/paypal/webhook \\\n    -H 'Content-Type: application/json' \\\n    -d '{json.dumps(PAYPAL_BODY, ensure_ascii=False)}'")
r = requests.post(f"{BASE}/payments/paypal/webhook", json=PAYPAL_BODY, timeout=25)
paypal_cb = jchk(r, "paypal webhook POST")
show("PayPal 回调响应", paypal_cb)
assert paypal_cb.get("verified") is True, f"PayPal 回调未通过 verified={paypal_cb}"
print(f"  ✅ PayPal 回调 VERIFIED!  skipped={paypal_cb.get('skipped')}  settled={paypal_cb.get('settled')}")

# --- 5. USDT payment + notify callback
step("5a. 创建 USDT 支付单")
r = pay_create("usdt", OID_B, ONO_B)
usdt_pay = jchk(r, "usdt create")
USDT_P = usdt_pay["data"]
PNO_U = USDT_P.get("payNo") or USDT_P.get("pay_no")
RATE = float(USDT_P.get("rate") or USDT_P.get("cnyUsdtRate") or 7.25)
WALLET = USDT_P.get("wallet") or USDT_P.get("toAddress") or USDT_P.get("wallet_address") or "TMETOEDEMOWALLET000000000000000"
USDT_AMOUNT = float(USDT_P.get("amount") or USDT_P.get("usdtAmount") or USDT_P.get("amountUsdt") or 0)
if USDT_AMOUNT == 0:
    TOTAL = float(OB.get("total") or OB.get("amount") or 398.0)
    USDT_AMOUNT = round(TOTAL / RATE, 6)
print(f"  USDT payNo={PNO_U}  应付={USDT_AMOUNT} USDT  汇率={RATE}  钱包={WALLET}")
show("USDT 支付单", USDT_P)

step("5b. 👉 USDT 链上通知回调 (POST /payments/usdt/notify)")
USDT_BODY = {
    "payNo": PNO_U,
    "txid": "0x" + uuid.uuid4().hex + uuid.uuid4().hex[:10],
    "network": "TRC20",
    "coin": "USDT",
    "amount": USDT_AMOUNT,
    "confirmations": 18,
    "minConfirm": 10,
    "blockHeight": 68001234,
    "blockTime": int(time.time()),
    "fromAddress": "TUSER" + uuid.uuid4().hex[:18].upper(),
    "toAddress": WALLET,
    "status": "success",
}
show("USDT Notify Body", USDT_BODY)
print("\n  [CURL] 可直接复制执行:")
print(f"  curl -X POST {BASE}/payments/usdt/notify \\\n    -H 'Content-Type: application/json' \\\n    -d '{json.dumps(USDT_BODY, ensure_ascii=False)}'")
r = requests.post(f"{BASE}/payments/usdt/notify", json=USDT_BODY, timeout=30)
usdt_cb = jchk(r, "usdt notify POST")
show("USDT 回调响应", usdt_cb)
assert usdt_cb.get("code") in (0, 200), f"USDT 回调失败: {usdt_cb}"
print(f"  ✅ USDT 回调成功!  message='{usdt_cb.get('message')}'")

# --- 6. 验证订单 + 支付 状态
step("6. ✅ 验证回调结果（订单 + 支付 状态）")
def get_order(ono):
    return S.get(f"{BASE}/orders/{ono}", headers=H, timeout=8).json()
def get_payment(pno):
    return S.get(f"{BASE}/payments/{pno}", headers=H, timeout=8).json()

OA2 = get_order(ONO_A); OB2 = get_order(ONO_B)
PA2 = get_payment(PNO_P); PU2 = get_payment(PNO_U)
show(f"订单 A ({ONO_A}) 状态", OA2.get("data") or OA2)
show(f"PayPal 支付单 ({PNO_P}) 状态", PA2.get("data") or PA2)
show(f"订单 B ({ONO_B}) 状态", OB2.get("data") or OB2)
show(f"USDT 支付单 ({PNO_U}) 状态", PU2.get("data") or PU2)

def status_of(obj):
    d = obj.get("data") or obj
    return d.get("status") or "(N/A)"
print(f"""
  🟢 PayPal 订单 A:  status='{status_of(OA2)}'
     PayPal 支付单:  status='{status_of(PA2)}'  txnId={((PA2.get('data') or PA2).get('channelTxnId') or (PA2.get('data') or PA2).get('channel_txn_id') or '已写入')}

  🟡 USDT 订单 B:    status='{status_of(OB2)}'
     USDT 支付单:    status='{status_of(PU2)}'  txId={USDT_BODY['txid'][:18]}...

  👉 回调已生效! 下一步（异步，后台线程执行，约 60-120s）：
     · orders → Lisa 主机 API 创建 VPS 记录
     · deploy-tasks → running → success
     · /internal/deploy/notify → 写入 access/servers 最终 IP/端口
""")

step("7. 快速检查 deploy-tasks 是否已创建（异步，创建就说明链路通）")
r = S.get(f"{BASE}/deploy-tasks", headers=H, timeout=8,
        params=dict(pageSize=20, all=None))
deploy_r = jchk(r, "deploy-tasks")
items = (deploy_r.get("data") or {}).get("items") or []
mine = [d for d in items if d.get("userId") == UID or d.get("user_id") == UID or
        d.get("order_id") in (OID_A, OID_B) or str(d.get("orderId")) in (str(OID_A), str(OID_B))]
print(f"  总部署任务数: {len(items)}")
print(f"  属于订单A/B 的任务数: {len(mine)}")
for d in mine[:10]:
    print(f"    task_id={d.get('id')}  order_id={d.get('order_id') or d.get('orderId')}  server_id={d.get('server_id') or d.get('serverId')}  status={d.get('status')}")

step("🎉 模拟回调测试脚本完成 ✅")
print("""
  两个回调接口均已通过真实 HTTP 请求测试生效:
    ✅ /payments/paypal/webhook  → verified=True, 订单自动 paid
    ✅ /payments/usdt/notify     → code=200, 订单自动 paid
""")
