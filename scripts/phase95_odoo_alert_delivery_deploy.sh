#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase95_alert_delivery_deploy_${TS}.txt"
OUT_JSON="logs/executive/phase95_odoo_alert_delivery_deploy_${TS}.json"
OUT_MD="docs/generated/phase95_odoo_alert_delivery_deploy_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"
: "${ODOO_URL:?}"
: "${ODOO_DB:?}"
: "${ODOO_ALERT_WEBHOOK:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
ENV_FILE=\"\${BASE_DIR}/alert.env\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"
LOG_DIR=\"\${BASE_DIR}/logs\"

mkdir -p \"\${BASE_DIR}\" \"\${LOG_DIR}\"

cat > \"\${ENV_FILE}\" <<EOF
ODOO_URL='${ODOO_URL}'
ODOO_DB='${ODOO_DB}'
ODOO_ALERT_WEBHOOK='${ODOO_ALERT_WEBHOOK}'
EOF

chmod 600 \"\${ENV_FILE}\"

cat > \"\${SEND_FILE}\" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\" && pwd)\"
ENV_FILE=\"\${BASE_DIR}/alert.env\"
LOG_DIR=\"\${BASE_DIR}/logs\"
mkdir -p \"\${LOG_DIR}\"

source \"\${ENV_FILE}\"
export ODOO_URL ODOO_DB ODOO_ALERT_WEBHOOK

TS=\"\$(date +%Y%m%d-%H%M%S)\"
OUT_JSON=\"\${LOG_DIR}/alert_delivery_\${TS}.json\"

python3 - <<'PY' > \"\${OUT_JSON}\"
import json, os, urllib.request
from datetime import datetime, timezone

def now():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

webhook = os.environ['ODOO_ALERT_WEBHOOK']
url = os.environ['ODOO_URL']
db = os.environ['ODOO_DB']

payload = {
    \"text\": f\"OK: watchdog remoto do ODOO testado com entrega real | db={db} | url={url} | created_at={now()}\"
}

body = json.dumps(payload).encode(\"utf-8\")
req = urllib.request.Request(
    webhook,
    data=body,
    headers={\"Content-Type\": \"application/json\"},
    method=\"POST\"
)

http_ok = False
status_code = 0
error = \"\"

try:
    with urllib.request.urlopen(req, timeout=20) as r:
        status_code = getattr(r, \"status\", 0)
        http_ok = 200 <= status_code < 300
except Exception as e:
    error = str(e)

out = {
    \"created_at\": now(),
    \"alert_delivery\": {
        \"http_ok\": http_ok,
        \"status_code\": status_code,
        \"message\": payload[\"text\"],
        \"url\": url,
        \"db\": db,
        \"error\": error
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

cat \"\${OUT_JSON}\"
EOF

chmod 700 \"\${SEND_FILE}\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== SEND FILE ====='
ls -l \"\${SEND_FILE}\"
echo
echo '===== TEST RUN ====='
\"\${SEND_FILE}\"
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
SCRIPT_OK=false
TEST_OK=false

grep -q 'send_alert.sh' "${RAW_FILE}" && SCRIPT_OK=true || true
grep -q '"http_ok": true' "${RAW_FILE}" && TEST_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --argjson script_ok "${SCRIPT_OK}" \
  --argjson test_ok "${TEST_OK}" \
  '{
    created_at: $created_at,
    alert_delivery_deploy: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      script_ok: $script_ok,
      test_ok: $test_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 95 — ODOO Alert Delivery Deploy

## Deploy
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- script_ok: ${SCRIPT_OK}
- test_ok: ${TEST_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] alert delivery deploy gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
