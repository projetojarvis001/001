#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase95_alert_delivery_probe_${TS}.txt"
OUT_JSON="logs/executive/phase95_odoo_alert_delivery_probe_${TS}.json"
OUT_MD="docs/generated/phase95_odoo_alert_delivery_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"

echo '===== SEND FILE ====='
ls -l \"\${BASE_DIR}/send_alert.sh\" || true
echo
echo '===== ALERT ENV ====='
ls -l \"\${BASE_DIR}/alert.env\" || true
echo
echo '===== LAST DELIVERY ====='
ls -1t \"\${LOG_DIR}\"/alert_delivery_*.json 2>/dev/null | head -n 1 | xargs -I{} sh -c 'echo {}; cat {}' || true
" > "${RAW_FILE}" 2>&1

SCRIPT_PRESENT=false
ENV_PRESENT=false
DELIVERY_OK=false

grep -q 'send_alert.sh' "${RAW_FILE}" && SCRIPT_PRESENT=true || true
grep -q 'alert.env' "${RAW_FILE}" && ENV_PRESENT=true || true
grep -q '"http_ok": true' "${RAW_FILE}" && DELIVERY_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson script_present "${SCRIPT_PRESENT}" \
  --argjson env_present "${ENV_PRESENT}" \
  --argjson delivery_ok "${DELIVERY_OK}" \
  '{
    created_at: $created_at,
    alert_delivery_probe: {
      raw_file: $raw_file,
      script_present: $script_present,
      env_present: $env_present,
      delivery_ok: $delivery_ok,
      overall_ok: ($script_present and $env_present and $delivery_ok)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 95 — ODOO Alert Delivery Probe

## Probe
- raw_file: ${RAW_FILE}
- script_present: ${SCRIPT_PRESENT}
- env_present: ${ENV_PRESENT}
- delivery_ok: ${DELIVERY_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] alert delivery probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
