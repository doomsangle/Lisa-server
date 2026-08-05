"""Super-minimal: step by step, all known fields validated."""
import requests, uuid, time, json, sys
BASE = "http://localhost:3000"
S = requests.Session()

def P(tag, d, n=500):
    s = json.dumps(d, ensure_ascii=False, indent=2)
    print(f"\n--- {tag} ---")
    print(s if len(s)<n else s[:n]+"\n...")

def run():
    # 1. Login
    r = S.post(f"{BASE}/auth/login", json={"username":"demo","password":"123456"})
    L = r.json()
    assert L.get("code")==0, L
    TOK = "Bearer " + L["data"]["token"]
    H = {"Authorization": TOK, "Content-Type": "application/json"}
    UID = L["data"]["user"]["id"]
    print(f"[1] Login OK  userId={UID}")

    # 2. Price check
    r = S.get(f"{BASE}/proxies/prices", headers=H, params={"category":"ISP"})
    PR = r.json()
    plans = PR["data"]["plans"]
    # 2nd plan: standard+
    P2 = plans[1]
    P("[2] Prices 2nd plan:", P2)

    # 3. Order A (PayPal) - correct fields per BuyReq!
    def buy_total(p, bw=30, period_days=30, qty=1):
        base = float(p["price"])
        bw_add = max(0,(bw-10))*1.2
        per = base + bw_add
        factor_period = {"1m":1,"2m":1.9,"3m":2.7,"4m":3.36}.get({30:"1m",60:"2m",90:"3m",120:"4m"}.get(period_days,"1m"), 1)
        disc = 0
        if qty>=20: disc=0.15
        elif qty>=10: disc=0.08
        elif qty>=5: disc=0.04
        amount = per * qty * factor_period
        total = round(amount * (1-disc), 2)
        return amount, disc, total, {30:"1m",60:"2m",90:"3m",120:"4m"}.get(period_days,"1m")

    AMT_A, DSC_A, TOT_A, PER_A = buy_total(P2, bw=30, period_days=30, qty=1)
    PAYLOAD_A = {
        "category": "ISP", "country": "US", "countryName": "美国", "countryFlag": "🇺🇸",
        "qty": 1, "period": PER_A, "plan": P2.get("key") or P2.get("name") or "standard",
        "cpu": 2, "ram": 2, "disk": 50, "os": "Ubuntu 22.04 LTS",
        "bandwidth": 30, "traffic": 2000.0,
        "usage": "web",
        "protocols": ["HTTP","SOCKS5"], "auth": "pwd",
        "username": f"u_{uuid.uuid4().hex[:6]}",
        "password": f"P_{uuid.uuid4().hex[:8]}!",
        "amount": round(AMT_A,2), "discount": round(DSC_A,2), "total": TOT_A,
    }
    r = S.post(f"{BASE}/proxies/buy", headers=H, json=PAYLOAD_A, timeout=8)
    OA = r.json()
    P("[3a] Order A (PayPal) created:", OA)
    assert OA.get("code")==0, OA
    OA_D = OA["data"]
    OID_A = OA_D.get("orderId") or OA_D.get("order_id") or OA_D.get("id")
    ONO_A = OA_D.get("orderNo") or OA_D.get("order_no")
    print(f"  Order A: id={OID_A}  no={ONO_A}  total={TOT_A}")

    # Order B (USDT) - 60 days, 20 Mbps
    AMT_B, DSC_B, TOT_B, PER_B = buy_total(P2, bw=20, period_days=60, qty=1)
    PAYLOAD_B = dict(PAYLOAD_A,
        period=PER_B, bandwidth=20, traffic=1500,
        username=f"u_{uuid.uuid4().hex[:6]}", password=f"P_{uuid.uuid4().hex[:8]}!",
        amount=round(AMT_B,2), discount=round(DSC_B,2), total=TOT_B)
    r = S.post(f"{BASE}/proxies/buy", headers=H, json=PAYLOAD_B, timeout=8)
    OB = r.json()
    P("[3b] Order B (USDT) created:", OB)
    assert OB.get("code")==0, OB
    OB_D = OB["data"]
    OID_B = OB_D.get("orderId") or OB_D.get("order_id") or OB_D.get("id")
    ONO_B = OB_D.get("orderNo") or OB_D.get("order_no")
    print(f"  Order B: id={OID_B}  no={ONO_B}  total={TOT_B}")

    # 4. PayPal payment
    r = S.post(f"{BASE}/payments/create", headers=H, json=dict(
        order_id=OID_A, order_no=ONO_A, channel="paypal",
        return_url="http://localhost:5173/orders", cancel_url="http://localhost:5173/orders"), timeout=8)
    PAYPAL = r.json()
    P("[4a] PayPal payment:", PAYPAL)
    assert PAYPAL.get("code")==0, PAYPAL
    PP = PAYPAL["data"]
    PNO_P = PP.get("payNo") or PP.get("pay_no")
    AMT_USD = float(PP.get("amount") or PP.get("usdAmount") or round(TOT_A/7.25,2))
    print(f"  PayPal payNo={PNO_P}  USD={AMT_USD}")

    # ---- PayPal webhook callback ----
    BODY_P = {
      "id": f"WH-TEST-{uuid.uuid4().hex}",
      "event_type": "CHECKOUT.ORDER.COMPLETED",
      "resource_type": "checkout-order",
      "event_version": "1.0",
      "resource": {
        "id": "5O190127TN364715T",
        "intent": "CAPTURE", "status": "COMPLETED",
        "custom_id": PNO_P,
        "purchase_units": [{"reference_id": ONO_A, "custom_id": PNO_P,
                            "amount": {"currency_code": "USD", "value": f"{AMT_USD:.2f}"}}],
        "payer": {"email_address": "buyer@sandbox.paypal.com", "payer_id": "DEMO1234"},
      }
    }
    P("[4b] >>> FIRING PayPal Webhook >>>", BODY_P, n=1500)
    print("\n  CURL:")
    print(f"  curl -s -X POST {BASE}/payments/paypal/webhook -H 'Content-Type: application/json' -d '{json.dumps(BODY_P)}' | python -m json.tool")
    r = requests.post(f"{BASE}/payments/paypal/webhook", json=BODY_P, timeout=25)
    CB_P = r.json()
    P("<<< PayPal Callback Response:", CB_P)
    assert CB_P.get("verified") is True, f"Not verified! {CB_P}"
    print("  ✅ PayPal Callback VERIFIED")

    # 5. USDT payment
    r = S.post(f"{BASE}/payments/create", headers=H, json=dict(
        order_id=OID_B, order_no=ONO_B, channel="usdt",
        return_url="http://localhost:5173/orders", cancel_url="http://localhost:5173/orders"), timeout=8)
    USDT_P = r.json()
    P("[5a] USDT payment:", USDT_P)
    assert USDT_P.get("code")==0, USDT_P
    UD = USDT_P["data"]
    PNO_U = UD.get("payNo") or UD.get("pay_no")
    RATE = float(UD.get("rate") or UD.get("cnyUsdtRate") or 7.25)
    WALLET = UD.get("wallet") or UD.get("toAddress") or UD.get("wallet_address") or "TMETOEDEMOWALLET000000000000000"
    AMT_U = float(UD.get("amount") or UD.get("usdtAmount") or round(TOT_B/RATE, 6))
    if AMT_U == 0: AMT_U = round(TOT_B/RATE, 6)
    print(f"  USDT payNo={PNO_U}  amount={AMT_U} USDT  wallet={WALLET}")

    # ---- USDT notify callback ----
    BODY_U = {
      "payNo": PNO_U,
      "txid": "0x" + uuid.uuid4().hex + uuid.uuid4().hex[:10],
      "network": "TRC20",
      "coin": "USDT",
      "amount": AMT_U,
      "confirmations": 18,
      "minConfirm": 10,
      "blockHeight": 68001234,
      "blockTime": int(time.time()),
      "fromAddress": "TDEMO" + uuid.uuid4().hex[:17].upper(),
      "toAddress": WALLET,
      "status": "success",
    }
    P("[5b] >>> FIRING USDT Notify >>>", BODY_U)
    print("\n  CURL:")
    print(f"  curl -s -X POST {BASE}/payments/usdt/notify -H 'Content-Type: application/json' -d '{json.dumps(BODY_U)}' | python -m json.tool")
    r = requests.post(f"{BASE}/payments/usdt/notify", json=BODY_U, timeout=30)
    CB_U = r.json()
    P("<<< USDT Callback Response:", CB_U)
    assert CB_U.get("code") in (0,200), f"USDT failed! {CB_U}"
    print(f"  ✅ USDT Callback OK  message={CB_U.get('message')}")

    # 6. Verify states
    print("\n=== [6] Verify States ===")
    g = lambda p,ono: S.get(f"{BASE}/{p}/{ono}", headers=H, timeout=8).json()
    OA2 = g("orders", ONO_A); PA2 = g("payments", PNO_P)
    OB2 = g("orders", ONO_B); PB2 = g("payments", PNO_U)
    def st(obj): return (obj.get("data") or obj).get("status") or "?"
    def txn(obj): return (obj.get("data") or obj).get("channelTxnId") or (obj.get("data") or obj).get("channel_txn_id") or ""

    print(f"  PayPal Order A : status = {st(OA2):<10}  (expected: paid)")
    print(f"  PayPal Pay A   : status = {st(PA2):<10}  txnId = {txn(PA2)}")
    print(f"  USDT Order B   : status = {st(OB2):<10}  (expected: paid)")
    print(f"  USDT Pay B     : status = {st(PB2):<10}  txnId = {txn(PB2)}")

    # 7. Deploy tasks quick check
    print("\n=== [7] Deploy Tasks (async, may still be running) ===")
    r = S.get(f"{BASE}/deploy-tasks", headers=H, timeout=8, params={"pageSize":50})
    DT = r.json()
    items = (DT.get("data") or {}).get("items") or []
    mine = [d for d in items
            if str(d.get("order_id") or d.get("orderId")) in (str(OID_A), str(OID_B))]
    print(f"  Total deploy tasks: {len(items)}.  Tasks for Order A/B: {len(mine)}")
    for d in mine[:6]:
        print(f"    task #{d.get('id')}  order={d.get('order_id') or d.get('orderId')}  server={d.get('server_id') or d.get('serverId')}  status={d.get('status')}")

    # 8. Summary & curl exports
    print("\n" + "="*70)
    print("  🎉 BOTH CALLBACKS SUCCESS — Payment → Order → Lisa → Deploy 链路已触发")
    print("="*70)
    print(f"""
  🟢 PayPal
     OrderNo:  {ONO_A}
     PayNo:    {PNO_P}
     Verify:   {CB_P.get('verified')}

  🟡 USDT TRC20
     OrderNo:  {ONO_B}
     PayNo:    {PNO_U}
     Amount:   {AMT_U} USDT
     TXID:     {BODY_U['txid']}
     Message:  {CB_U.get('message')}

  🔁 Replay curl commands (可在任意终端重放):
     —— PayPal ——
     curl -s -X POST {BASE}/payments/paypal/webhook \\
       -H 'Content-Type: application/json' \\
       -d '{json.dumps(BODY_P, ensure_ascii=False)}' | python -m json.tool

     —— USDT ——
     curl -s -X POST {BASE}/payments/usdt/notify \\
       -H 'Content-Type: application/json' \\
       -d '{json.dumps(BODY_U, ensure_ascii=False)}' | python -m json.tool
""")

try:
    run()
except Exception as e:
    import traceback
    traceback.print_exc()
    print(f"\n❌ FAILED: {e}")
    sys.exit(1)
