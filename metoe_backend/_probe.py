import requests, json, traceback
r = requests.post("http://localhost:3000/auth/login", json={"username":"demo","password":"123456"})
print("status:", r.status_code)
print(json.dumps(r.json(), indent=2, ensure_ascii=False))
# Also check if backend reports errors, hit /docs for trace
