# Step 1 balance payment test
import requests, sys, time, json
BASE='http://localhost:3000'
r=requests.post(f'{BASE}/auth/login', json={'username':'demo','password':'123456'}, timeout=10)
tok=r.json()['data']['token']
H={'Authorization':'Bearer '+tok}
buy=dict(category='ISP',country='US',countryName='US',countryFlag='F',qty=1,period='1m',plan='standard',amount=149.0,discount=0,total=149.0,protocols=['HTTP'],auth='pwd')
r=requests.post(f'{BASE}/proxies/buy', json=buy, headers=H, timeout=20)
print('BUY', r.status_code, r.json().get('message'))
ono=r.json()['data']['orderNo']
r=requests.post(f'{BASE}/orders/{ono}/pay', json={'channel':'balance'}, headers=H, timeout=20)
jr=r.json(); print('PAY', r.status_code, jr.get('code'), jr.get('message'))
d=jr.get('data') or {}
print('paid', d.get('paid'), 'depid', d.get('deploy_id'))
with open('tmp_res.json','w') as f: json.dump({'tok':tok,'ono':ono,'depid':d.get('deploy_id')}, f)
sys.exit(0 if d.get('paid') else 1)
