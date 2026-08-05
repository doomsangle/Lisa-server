# -*- coding: utf-8 -*-
import sys, os, json, uuid, time, requests
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")
BASE = os.environ.get("METOE_API_BASE") or "http://localhost:3000"
HERE = os.path.dirname(os.path.abspath(__file__))
s = requests.Session()

L = s.post(f"{BASE}/auth/login", json={"username":"demo","password":"123456"}).json()
assert L.get("code") == 0, L
TOK = "Bearer " + L["data"]["token"]
H = {"Authorization": TOK, "Content-Type": "application/json"}
UID = L["data"]["user"]["id"]

# Already created orders
OID_A, ONO_A = 12, "PO17845378626854746"
PNO_P, USD_A  = "PAY1784537899338311", 20.55
OID_B, ONO_B, TOT_B = 13, "PO17845378993101075", 305.9

print(f"[1] login OK, uid={UID}")

# 1. Create USDT payment for order B
r = s.post(f"{BASE}/payments/create", headers=H, json={
    "order_id": OID_B, "order_no": ONO_B, "channel": "usdt",
    "return_url": "x", "cancel_url": "x",
}, timeout=15)
US = r.json()
print(f"[2] USDT payment create: code={US.get('code')} msg={US.get('message')}")
assert US.get("code") in (0, 200, 201), US
UD = US["data"]
PNO_U   = UD.get("payNo") or UD.get("pay_no")
RATE    = float(UD.get("rate") or UD.get("cnyUsdtRate") or 7.25)
WALLET  = UD.get("wallet") or UD.get("toAddress") or UD.get("wallet_address") or "TMETOE000000000000000000000000"
USDT_AMT = float(UD.get("amount") or UD.get("usdtAmount") or round(TOT_B/RATE, 6))
if USDT_AMT == 0:
    USDT_AMT = round(TOT_B / RATE, 6)
print(f"    PayNo={PNO_U}  Amount={USDT_AMT} USDT  Rate={RATE}  Wallet={WALLET}")

# Save full state
STATE = dict(uid=UID,oid_a=OID_A,ono_a=ONO_A,pno_p=PNO_P,usd_a=USD_A,
             oid_b=OID_B,ono_b=ONO_B,pno_u=PNO_U,rate=RATE,wallet=WALLET,usdt_amt=USDT_AMT)
with open(os.path.join(HERE, "__tmp_step_data.json"), "w", encoding="utf-8") as f:
    json.dump(STATE, f, ensure_ascii=False, indent=2)

# 2. PayPal callback
BODYP = {
    "id": f"WH-TEST-{uuid.uuid4().hex}",
    "event_type": "CHECKOUT.ORDER.COMPLETED",
    "resource_type": "checkout-order",
    "event_version": "1.0",
    "resource": {
        "id": "5O190127TN364715T",
        "intent": "CAPTURE",
        "status": "COMPLETED",
        "custom_id": PNO_P,
        "purchase_units": [{
            "reference_id": ONO_A,
            "custom_id": PNO_P,
            "amount": {"currency_code": "USD", "value": f"{USD_A:.2f}"},
        }],
        "payer": {"email_address": "buyer@sandbox.paypal.com", "payer_id": "DEMO1234"},
    },
}
print("\n[3] POST /payments/paypal/webhook ...")
rp = requests.post(f"{BASE}/payments/paypal/webhook", json=BODYP, timeout=30)
CBP = rp.json()
print(f"    HTTP {rp.status_code}  verified={CBP.get('verified')}  skipped={CBP.get('skipped')}  settled={CBP.get('settled')}")
print(f"    msg={CBP.get('message')}")
print(f"    full response = {json.dumps(CBP, ensure_ascii=False)[:600]}")

# 3. USDT callback
BODYU = {
    "payNo": PNO_U,
    "txid": "0x" + uuid.uuid4().hex + uuid.uuid4().hex[:10],
    "network": "TRC20",
    "coin": "USDT",
    "amount": USDT_AMT,
    "confirmations": 18,
    "minConfirm": 10,
    "blockHeight": 68001234,
    "blockTime": int(time.time()),
    "fromAddress": "TDEMO" + uuid.uuid4().hex[:17].upper(),
    "toAddress": WALLET,
    "status": "success",
}
print("\n[4] POST /payments/usdt/notify ...")
ru = requests.post(f"{BASE}/payments/usdt/notify", json=BODYU, timeout=30)
CBU = ru.json()
print(f"    HTTP {ru.status_code}  code={CBU.get('code')}  message={CBU.get('message')}")
print(f"    full response = {json.dumps(CBU, ensure_ascii=False)[:600]}")

with open(os.path.join(HERE, "__tmp_cb_results.json"), "w", encoding="utf-8") as f:
    json.dump({"paypal_cb": CBP, "usdt_cb": CBU,
               "paypal_body": BODYP, "usdt_body": BODYU,
               **STATE}, f, ensure_ascii=False, indent=2)

print("\n[DONE] Callbacks fired.")
assert CBP.get("verified") is True, f"PayPal not verified: {CBP}"
assert CBU.get("code") in (0, 200, 201), f"USDT callback failed: {CBU}"
print("\nALL CALLBACKS PASSED.")
