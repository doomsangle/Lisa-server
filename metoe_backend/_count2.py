import re, sys
# Proxies INSERT from pipeline.py
sql = """INSERT INTO proxies
           (user_id, category, country_code, country_name, country_flag, type, protocol, ip, port, username, password,
            traffic_used, traffic_total, threads_limit, auth_type, status, expire_at, order_id, server_id, deploy_task_id)
           VALUES (?,?,?,?,?,?, 'HTTP,SOCKS5',?,?,?,?,0,?,100,'pwd','deploying',?,?,?,?,?)"""

# Normalize to one line
oneline = ' '.join(l.strip() for l in sql.split('\n') if l.strip())
print('ONELINE:', oneline)
# Extract columns
cols_re = re.search(r'INSERT INTO proxies\s*\((.*?)\)\s*VALUES\s*\((.*?)\)$', oneline, re.I)
cols = [c.strip() for c in cols_re.group(1).split(',') if c.strip()]
vals_raw = cols_re.group(2)
print('cols count:', len(cols), cols)
print('vals_raw:', repr(vals_raw))
# Parse entries respecting single quotes
entries=[]; buf=''; in_q=False
for ch in vals_raw:
    if ch=="'":
        in_q = not in_q; buf+=ch
    elif ch==',' and not in_q:
        entries.append(buf.strip()); buf=''
    else:
        buf+=ch
if buf: entries.append(buf.strip())
print('entries count:', len(entries))
for i,e in enumerate(entries): print(f'  #{i}: {e}')
print(' ? count:', vals_raw.count('?'))
print(' literals:', [e for e in entries if not e.startswith('?') and e!='?'])
