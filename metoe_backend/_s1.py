"""E2E step 1+2: test balance payment ONLY"""
import requests, time, sys, json
BASE='http://localhost:3000'
r = requests.post(f'{BASE}/auth/login', json={'username':'demo','password':'123456'})
d = r.json()['data']; tok=d['token']; H={'Authorization': f'Bearer {tok}'}
print('login ok, bal=', d['user']['balance'])
buy = dict(category='ISP',country='US',countryName='美国',countryFlag='🇺🇸',
    qty=1,period='1m',plan='standard',amount=149.0,discount=0,total=149.0,
    protocols=['HTTP','SOCKS5'],auth='pwd')
r = requests.post(f'{BASE}/proxies/buy', json=buy, headers=H); 
print('buy:', r.status_code, r.json()['message'])
ono = r.json()['data']['orderNo']
print('orderNo:', ono)
r = requests.post(f'{BASE}/orders/{ono}/pay', json={'channel':'balance'}, headers=H)
print('pay status:', r.status_code)
jr = r.json()
print('code:', jr.get('code'))
print('message:', jr.get('message'))
dd = jr.get('data')
if dd:
    print('data keys:', list(dd.keys()))
    paid = dd.get('paid'); depid = dd.get('deploy_id')
    print(f'paid={paid} depid={depid}')
    # write next step info to JSON for later run
    with open('_tmp_step.json','w',encoding='utf-8') as f:
        json.dump({'tok':tok,'ono':ono,'depid':depid},f)
    sys.exit(0 if paid else 2)
sys.exit(1)
