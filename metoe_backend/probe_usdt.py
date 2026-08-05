import sys, os, json, requests
HERE = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(HERE, "__probe.txt")
with open(path, "w", encoding="utf-8") as f:
    f.write("HELLO\n")
print("Probe file written.")
sys.stdout.flush()

r = requests.post("http://localhost:3000/auth/login", json={"username":"demo","password":"123456"})
L = r.json()
with open(path, "a", encoding="utf-8") as f:
    f.write(f"LOGIN code={L.get('code')}\n")
print(f"Login done. code={L.get('code')}")
sys.stdout.flush()

TOK = "Bearer " + L["data"]["token"]
H = {"Authorization": TOK, "Content-Type": "application/json"}
s = requests.Session()
r = s.post("http://localhost:3000/payments/create", headers=H, json={
    "order_id": 13, "order_no": "PO17845378993101075", "channel": "usdt",
    "return_url": "x", "cancel_url": "x",
}, timeout=15)
US = r.json()
with open(path, "a", encoding="utf-8") as f:
    f.write(f"USDT_PAY code={US.get('code')}\nFULL={json.dumps(US, ensure_ascii=False)}\n")
print(f"USDT payment done. code={US.get('code')}")
sys.stdout.flush()

with open(os.path.join(HERE, "__usdt.json"), "w", encoding="utf-8") as f:
    json.dump(US, f, ensure_ascii=False, indent=2)
print("USDT result saved to __usdt.json")
sys.stdout.flush()
