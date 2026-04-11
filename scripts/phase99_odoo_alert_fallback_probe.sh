#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase99_alert_fallback_probe_${TS}.txt"
OUT_JSON="logs/executive/phase99_odoo_alert_fallback_probe_${TS}.json"
OUT_MD="docs/generated/phase99_odoo_alert_fallback_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" \
  ssh -T -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
  "ODOO_SSH_USER='${ODOO_SSH_USER}' bash -s" > "${RAW_FILE}" 2>&1 <<'REMOTE'
set -euo pipefail

BASE_DIR="/home/${ODOO_SSH_USER}/odoo_watchdog"
LOG_DIR="${BASE_DIR}/logs"
FAILED_DIR="${LOG_DIR}/failed_queue"

"${BASE_DIR}/send_alert.sh"

echo '===== LAST SUCCESS ALERT ====='
LAST_ALERT=$(ls -1t "${LOG_DIR}"/alert_delivery_*.json 2>/dev/null | head -n 1 || true)
echo "${LAST_ALERT}"
[ -n "${LAST_ALERT}" ] && cat "${LAST_ALERT}"
echo
echo '===== FAILED QUEUE COUNT ====='
find "${FAILED_DIR}" -maxdepth 1 -type f -name 'alert_failed_*.json' | wc -l
REMOTE

SUCCESS_OK=false
QUEUE_VISIBLE=false

grep -q '"http_ok": true' "${RAW_FILE}" && SUCCESS_OK=true || true
grep -q 'FAILED QUEUE COUNT' "${RAW_FILE}" && QUEUE_VISIBLE=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson success_ok "${SUCCESS_OK}" \
  --argjson queue_visible "${QUEUE_VISIBLE}" \
  '{
    created_at: $created_at,
    fallback_probe: {
      raw_file: $raw_file,
      success_ok: $success_ok,
      queue_visible: $queue_visible,
      overall_ok: ($success_ok and $queue_visible)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 99 — ODOO Alert Fallback Probe

## Probe
- raw_file: ${RAW_FILE}
- success_ok: ${SUCCESS_OK}
- queue_visible: ${QUEUE_VISIBLE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] fallback probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
