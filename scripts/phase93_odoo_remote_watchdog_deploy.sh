#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase93_remote_watchdog_deploy_${TS}.txt"
OUT_JSON="logs/executive/phase93_odoo_remote_watchdog_deploy_${TS}.json"
OUT_MD="docs/generated/phase93_odoo_remote_watchdog_deploy_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"
: "${ODOO_URL:?}"
: "${ODOO_DB:?}"
: "${ODOO_APP_USER:?}"
: "${ODOO_APP_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
ENV_FILE=\"\${BASE_DIR}/.env\"
RUN_FILE=\"\${BASE_DIR}/watchdog_run.sh\"
LOG_DIR=\"\${BASE_DIR}/logs\"
STAMP_FILE=\"\${LOG_DIR}/last_run.ok\"
JSON_FILE=\"\${LOG_DIR}/last_run.json\"
CRON_TMP=\"/tmp/odoo_watchdog_cron_${TS}.txt\"

mkdir -p \"\${BASE_DIR}\" \"\${LOG_DIR}\"

cat > \"\${ENV_FILE}\" <<EOF
ODOO_URL='${ODOO_URL}'
ODOO_DB='${ODOO_DB}'
ODOO_APP_USER='${ODOO_APP_USER}'
ODOO_APP_PASS='${ODOO_APP_PASS}'
EOF

chmod 600 \"\${ENV_FILE}\"

cat > \"\${RUN_FILE}\" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\" && pwd)\"
LOG_DIR=\"\${BASE_DIR}/logs\"
ENV_FILE=\"\${BASE_DIR}/.env\"
mkdir -p \"\${LOG_DIR}\"

source \"\${ENV_FILE}\"

TS=\"\$(date +%Y%m%d-%H%M%S)\"
OUT_JSON=\"\${LOG_DIR}/watchdog_\${TS}.json\"
OUT_LOG=\"\${LOG_DIR}/watchdog_\${TS}.log\"
LAST_JSON=\"\${LOG_DIR}/last_run.json\"
STAMP_FILE=\"\${LOG_DIR}/last_run.ok\"

python3 - <<'PY' > \"\${OUT_JSON}\"
import json, os, urllib.request, xmlrpc.client
from datetime import datetime, timezone

def now():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

url = os.environ['ODOO_URL'].rstrip('/')
db = os.environ['ODOO_DB']
user = os.environ['ODOO_APP_USER']
password = os.environ['ODOO_APP_PASS']

target = url + '/web/login'
http_ok = False
login_ok = False
status_code = 0
server_header = ''
web_error = ''

rpc_ok = False
auth_ok = False
uid = 0
server_version = ''
protocol_version = 0
rpc_error = ''

try:
    req = urllib.request.Request(target, method='GET')
    with urllib.request.urlopen(req, timeout=20) as r:
        body = r.read().decode('utf-8', errors='ignore')
        status_code = getattr(r, 'status', 0)
        http_ok = status_code == 200
        login_ok = ('login' in body.lower()) or ('odoo' in body.lower())
        server_header = r.headers.get('Server', '')
except Exception as e:
    web_error = str(e)

try:
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common', allow_none=True)
    version = common.version()
    rpc_ok = True
    server_version = version.get('server_version', '')
    protocol_version = version.get('protocol_version', 0)
    uid = common.authenticate(db, user, password, {})
    auth_ok = bool(uid)
except Exception as e:
    rpc_error = str(e)

payload = {
    'created_at': now(),
    'watchdog': {
        'url': url,
        'db': db,
        'web_ok': http_ok,
        'login_ok': login_ok,
        'status_code': status_code,
        'server_header': server_header,
        'rpc_ok': rpc_ok,
        'auth_ok': auth_ok,
        'uid': uid,
        'server_version': server_version,
        'protocol_version': protocol_version,
        'web_error': web_error,
        'rpc_error': rpc_error,
        'overall_ok': all([http_ok, login_ok, rpc_ok, auth_ok])
    }
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

cp \"\${OUT_JSON}\" \"\${LAST_JSON}\"

python3 - <<'PY' > \"\${OUT_LOG}\"
import json, os
from pathlib import Path
p = Path(os.environ['LAST_JSON'])
data = json.loads(p.read_text())
w = data['watchdog']
print('overall_ok=' + str(w['overall_ok']).lower())
print('web_ok=' + str(w['web_ok']).lower())
print('login_ok=' + str(w['login_ok']).lower())
print('rpc_ok=' + str(w['rpc_ok']).lower())
print('auth_ok=' + str(w['auth_ok']).lower())
print('server_header=' + w.get('server_header',''))
print('server_version=' + w.get('server_version',''))
print('uid=' + str(w.get('uid',0)))
PY

if jq -e '.watchdog.overall_ok == true' \"\${OUT_JSON}\" >/dev/null; then
  date -u +'%Y-%m-%dT%H:%M:%SZ' > \"\${STAMP_FILE}\"
fi
EOF

chmod 700 \"\${RUN_FILE}\"

( crontab -l 2>/dev/null | grep -v 'odoo_watchdog/watchdog_run.sh' || true ) > \"\${CRON_TMP}\"
echo '*/5 * * * * /home/${ODOO_SSH_USER}/odoo_watchdog/watchdog_run.sh >> /home/${ODOO_SSH_USER}/odoo_watchdog/logs/cron_stdout.log 2>&1' >> \"\${CRON_TMP}\"
crontab \"\${CRON_TMP}\"
rm -f \"\${CRON_TMP}\"

\"\${RUN_FILE}\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== CRONTAB ====='
crontab -l
echo
echo '===== LAST JSON ====='
cat \"\${JSON_FILE}\"
echo
echo '===== LAST STAMP ====='
cat \"\${STAMP_FILE}\"
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CRON_OK=false
RUN_OK=false
STAMP_OK=false

grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_OK=true || true
grep -q '"overall_ok": true' "${RAW_FILE}" && RUN_OK=true || true
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "${RAW_FILE}" && STAMP_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --argjson cron_ok "${CRON_OK}" \
  --argjson run_ok "${RUN_OK}" \
  --argjson stamp_ok "${STAMP_OK}" \
  '{
    created_at: $created_at,
    remote_watchdog_deploy: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      cron_ok: $cron_ok,
      run_ok: $run_ok,
      stamp_ok: $stamp_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 93 — ODOO Remote Watchdog Deploy

## Deploy
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- cron_ok: ${CRON_OK}
- run_ok: ${RUN_OK}
- stamp_ok: ${STAMP_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] remote watchdog deploy gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
