"""Check INSERT statements columns vs placeholder counts in pipeline.py"""
import re, sys
sys.path.insert(0, '.')
from core.database import get_conn

with open('services/pipeline.py', encoding='utf-8') as f:
    src = f.read()

# Find multi-line INSERT blocks
sql_blocks = re.findall(r'"""(INSERT.*?)"""', src, re.S)

for blk in sql_blocks:
    lines = [l.rstrip() for l in blk.strip().split('\n') if l.strip() and not l.strip().startswith('#')]
    full_sql = ' '.join(lines)
    # column list
    m = re.search(r'INSERT INTO\s+(\w+)\s*\((.*?)\)\s*VALUES\s*\((.*)\)', full_sql, re.I | re.S)
    if not m:
        continue
    table, cols_str, vals_str = m.group(1), m.group(2), m.group(3)
    cols = [c.strip() for c in cols_str.split(',') if c.strip()]
    vals_parts = re.split(r',\s*', vals_str)
    placeholders = vals_str.count('?')
    literals = 0
    for v in vals_parts:
        v = v.strip()
        if v and v != '?' and not v.startswith('?'):
            literals += 1
    print(f"TABLE {table}: cols={len(cols):2d}  ?={placeholders:2d}  literals={literals:2d}  total_vals={placeholders+literals:2d}  cols==vals? {len(cols)==placeholders+literals}")
    if len(cols) != placeholders+literals:
        col_names = [re.sub(r'[`"\[\]]','',c).lower() for c in cols]
        print(f"  COLS: {cols}")
        print(f"  VALS: {vals_parts}")
        print(f"  -> 差额: cols={len(cols)}, 需要 placeholders+literals={len(cols)}, 实际={placeholders+literals}")
