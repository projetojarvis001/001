#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

FILE="docker-compose.yml"

if [ ! -f "${FILE}" ]; then
  echo "[ERRO] docker-compose.yml nao encontrado"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
txt = p.read_text()

m_db = re.search(r'POSTGRES_DB:\s*([^\n]+)', txt)
m_user = re.search(r'POSTGRES_USER:\s*([^\n]+)', txt)

if not m_db or not m_user:
    raise SystemExit("[ERRO] nao encontrei POSTGRES_DB/POSTGRES_USER no compose")

db = m_db.group(1).strip().strip("'\"")
user = m_user.group(1).strip().strip("'\"")

pattern = r'(DATABASE_URL=postgres://)([^:]+):([^@]+)@postgres:5432/([^"\n]+)'
repl = rf'\1{user}:\3@postgres:5432/{db}'

new_txt, n = re.subn(pattern, repl, txt, count=1)

if n == 0:
    raise SystemExit("[ERRO] nao consegui ajustar DATABASE_URL")

p.write_text(new_txt)
print("[OK] DATABASE_URL alinhada ao compose")
PY
