#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase98_watchdog_restore_probe_${TS}.txt"
OUT_JSON="logs/executive/phase98_odoo_watchdog_restore_probe_${TS}.json"
OUT_MD="docs/generated/phase98_odoo_watchdog_restore_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"

echo '===== FORCE ALERT RUN ====='
\"\${SEND_FILE}\"
echo
echo '===== LAST WATCHDOG JSON ====='
LAST_JSON=\"\${LOG_DIR}/last_run.json\"
echo \"\${LAST_JSON}\"
[ -f \"\${LAST_JSON}\" ] && cat \"\${LAST_JSON}\"
echo
echo '===== LAST ALERT DELIVERY ====='
LAST_ALERT=\$(ls -1t \"\${LOG_DIR}\"/alert_delivery_*.json 2>/dev/null | head -n 1 || true)
echo \"\$LAST_ALERT\"
[ -n \"\$LAST_ALERT\" ] && cat \"\$LAST_ALERT\"
" > "${RAW_FILE}" 2>&1

WATCHDOG_OK=false
ALERT_OK=false

grep -q '"overall_ok": true' "${RAW_FILE}" && WATCHDOG_OK=true || true
grep -q '"http_ok": true' "${RAW_FILE}" && ALERT_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson watchdog_ok "${WATCHDOG_OK}" \
  --argjson alert_ok "${ALERT_OK}" \
  '{
    created_at: $created_at,
    restore_probe: {
      raw_file: $raw_file,
      watchdog_ok: $watchdog_ok,
      alert_ok: $alert_ok,
      overall_ok: ($watchdog_ok and $alert_ok)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 98A — ODOO Watchdog Restore Probe Fix

## Probe
- raw_file: ${RAW_FILE}
- watchdog_ok: ${WATCHDOG_OK}
- alert_ok: ${ALERT_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] restore probe 98A gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
