"""Step 1: Login + get token + create Order A and B + write JSON."""
import sys, os, json, uuid, requests
sys.stdout.reconfigure(encoding="utf-8")
BASE = os.environ.get("METOE_API_BASE") or "http://localhost:3000"
HERE = os.path.dirname(os.path.abspath(__file__))
S = requests.Session()

r = S.post(f"{BASE}/auth/login", json={"username":"demo","password":"123456"}, timeout=8)
L = r.json(); assert L.get("code")==0, f"Login failed: {L}"
TOK = "Bearer " + L["data"]["token"]
UID = L["data"]["user"]["id"]
H = {"Authorization": TOK, "Content-Type": "application/json"}

r = S.get(f"{BASE}/proxies/prices", headers=H, params={"category":"ISP"}, timeout=8)
PR = r.json(); P2 = PR["data"]["plans"][1]  # standard+

def make_buy(p, bw=30, days=30):
    base = float(p["price"])
    bw_add = max(0,(bw-10))*1.2
    pm = {30:"1m",60:"2m",90:"3m",120:"4m"}.get(days,"1m")
    fp = {"1m":1,"2m":1.9,"3m":2.7,"4m":3.36}[pm]
    amt = (base + bw_add) * 1 * fp
    tot = round(amt,2)
    return {
        "category":"ISP","country":"US","countryName":"美国","countryFlag":"🇺🇸",
        "qty":1,"period":pm,"plan":(p.get("key") or p.get("name") or "standard"),
        "cpu":2,"ram":2,"disk":50,"os":"Ubuntu 22.04 LTS",
        "bandwidth":bw,"traffic":2000.0 if days<60 else 1500,
        "usage":"web","protocols":["HTTP","SOCKS5"],"auth":"pwd",
        "username":f"u_{uuid.uuid4().hex[:6]}","password":f"P_{uuid.uuid4().hex[:8]}!",
        "amount":round(amt,2),"discount":0.0,"total":tot,
    }, tot

pA, tA = make_buy(P2, bw=30, days=30)
pB, tB = make_buy(P2, bw=20, days=60)

rA = S.post(f"{BASE}/proxies/buy", headers=H, json=pA, timeout=10).json(); assert rA.get("code")==0, rA
rB = S.post(f"{BASE}/proxies/buy", headers=H, json=pB, timeout=10).json(); assert rB.get("code")==0, rB
OA = rA["data"]; OB = rB["data"]
OID_A = OA.get("orderId") or OA.get("order_id") or OA.get("id"); ONO_A = OA.get("orderNo") or OA.get("order_no")
OID_B = OB.get("orderId") or OB.get("order_id") or OB.get("id"); ONO_B = OB.get("orderNo") or OB.get("order_no")

# Create payments
rP = S.post(f"{BASE}/payments/create", headers=H, json=dict(order_id=OID_A,order_no=ONO_A,channel="paypal",return_url="x",cancel_url="x"), timeout=10).json(); assert rP.get("code")==0, rP
rU = S.post(f"{BASE}/payments/create", headers=H, json=dict(order_id=OID_B,order_no=ONO_B,channel="usdt",return_url="x",cancel_url="x"), timeout=10).json(); assert rU.get("code")==0, rU
PP = rP["data"]; UD = rU["data"]
PNO_P = PP.get("payNo") or PP.get("pay_no")
PNO_U = UD.get("payNo") or UD.get("pay_no")
RATE = float(UD.get("rate") or UD.get("cnyUsdtRate") or 7.25)
WALLET = UD.get("wallet") or UD.get("toAddress") or UD.get("wallet_address") or "TMETOEDEMO0000000000000000000"
USD_A = float(PP.get("amount") or PP.get("usdAmount") or round(tA/RATE,2))
USDT_AMT = float(UD.get("amount") or UD.get("usdtAmount") or round(tB/RATE,6))
if USDT_AMT == 0: USDT_AMT = round(tB/RATE,6)

DATA = dict(
    base=BASE, token=TOK, uid=UID,
    oid_a=OID_A, ono_a=ONO_A, tot_a=tA,
    oid_b=OID_B, ono_b=ONO_B, tot_b=tB,
    pno_p=PNO_P, usd_a=USD_A,
    pno_u=PNO_U, rate=RATE, wallet=WALLET, usdt_amt=USDT_AMT,
)
with open(os.path.join(HERE, "__tmp_step1.json"), "w", encoding="utf-8") as f:
    json.dump(DATA, f, ensure_ascii=False, indent=2)
print(f"OK  OID_A={OID_A}({ONO_A})  OID_B={OID_B}({ONO_B})  PayPalNo={PNO_P}${USD_A:.2f}  USDTNo={PNO_U}{USDT_AMT:.6f}@{WALLET}")
