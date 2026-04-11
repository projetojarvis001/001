#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase100_closure_inventory_${TS}.txt"
OUT_JSON="logs/executive/phase100_odoo_closure_inventory_${TS}.json"
OUT_MD="docs/generated/phase100_odoo_closure_inventory_${TS}.md"

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

echo '===== BASE DIR ====='
echo "${BASE_DIR}"
echo
echo '===== TREE ====='
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo
echo '===== CRONTAB ====='
crontab -l || true
echo
echo '===== LAST RUN JSON ====='
[ -f "${LOG_DIR}/last_run.json" ] && cat "${LOG_DIR}/last_run.json"
echo
echo '===== LAST ALERT JSON ====='
LAST_ALERT=$(ls -1t "${LOG_DIR}"/alert_delivery_*.json 2>/dev/null | head -n 1 || true)
echo "${LAST_ALERT}"
[ -n "${LAST_ALERT}" ] && cat "${LAST_ALERT}"
echo
echo '===== FAILED QUEUE COUNT ====='
find "${FAILED_DIR}" -maxdepth 1 -type f -name 'alert_failed_*.json' | wc -l
REMOTE

WATCHDOG_FILE=false
RETENTION_FILE=false
ALERT_FILE=false
LAST_RUN_OK=false
LAST_ALERT_OK=false
CRON_WATCHDOG=false
CRON_RETENTION=false
FAILED_QUEUE_VISIBLE=false

grep -q 'watchdog_run.sh' "${RAW_FILE}" && WATCHDOG_FILE=true || true
grep -q 'retention' "${RAW_FILE}" && RETENTION_FILE=true || true
grep -q 'send_alert.sh' "${RAW_FILE}" && ALERT_FILE=true || true
grep -q '"overall_ok": true' "${RAW_FILE}" && LAST_RUN_OK=true || true
grep -q '"http_ok": true' "${RAW_FILE}" && LAST_ALERT_OK=true || true
grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_WATCHDOG=true || true
grep -q 'retention' "${RAW_FILE}" && CRON_RETENTION=true || true
grep -q 'FAILED QUEUE COUNT' "${RAW_FILE}" && FAILED_QUEUE_VISIBLE=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson watchdog_file "${WATCHDOG_FILE}" \
  --argjson retention_file "${RETENTION_FILE}" \
  --argjson alert_file "${ALERT_FILE}" \
  --argjson last_run_ok "${LAST_RUN_OK}" \
  --argjson last_alert_ok "${LAST_ALERT_OK}" \
  --argjson cron_watchdog "${CRON_WATCHDOG}" \
  --argjson cron_retention "${CRON_RETENTION}" \
  --argjson failed_queue_visible "${FAILED_QUEUE_VISIBLE}" \
  '{
    created_at: $created_at,
    closure_inventory: {
      raw_file: $raw_file,
      watchdog_file: $watchdog_file,
      retention_file: $retention_file,
      alert_file: $alert_file,
      last_run_ok: $last_run_ok,
      last_alert_ok: $last_alert_ok,
      cron_watchdog: $cron_watchdog,
      cron_retention: $cron_retention,
      failed_queue_visible: $failed_queue_visible,
      overall_ok: (
        $watchdog_file and
        $retention_file and
        $alert_file and
        $last_run_ok and
        $last_alert_ok and
        $cron_watchdog and
        $cron_retention and
        $failed_queue_visible
      )
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 100 — ODOO Closure Inventory

## Inventory
- raw_file: ${RAW_FILE}
- watchdog_file: ${WATCHDOG_FILE}
- retention_file: ${RETENTION_FILE}
- alert_file: ${ALERT_FILE}
- last_run_ok: ${LAST_RUN_OK}
- last_alert_ok: ${LAST_ALERT_OK}
- cron_watchdog: ${CRON_WATCHDOG}
- cron_retention: ${CRON_RETENTION}
- failed_queue_visible: ${FAILED_QUEUE_VISIBLE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] closure inventory gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
