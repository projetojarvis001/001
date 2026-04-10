#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase94_remote_watchdog_retention_probe_${TS}.txt"
OUT_JSON="logs/executive/phase94_odoo_watchdog_retention_probe_${TS}.json"
OUT_MD="docs/generated/phase94_odoo_watchdog_retention_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"

echo '===== FILES ====='
ls -la \"\${BASE_DIR}\" || true
echo
echo '===== LOGS ====='
ls -la \"\${LOG_DIR}\" || true
echo
echo '===== CRONTAB ====='
crontab -l || true
echo
echo '===== RETENTION DRY SIGNAL ====='
\" \${BASE_DIR}/retention.sh\" 2>/dev/null || \"\${BASE_DIR}/retention.sh\"
" > "${RAW_FILE}" 2>&1

SCRIPT_PRESENT=false
CRON_PRESENT=false
RETENTION_OK=false

grep -q 'retention.sh' "${RAW_FILE}" && SCRIPT_PRESENT=true || true
grep -q '17 2 \* \* \* /home/' "${RAW_FILE}" && CRON_PRESENT=true || true
grep -q 'json_count=' "${RAW_FILE}" && RETENTION_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson script_present "${SCRIPT_PRESENT}" \
  --argjson cron_present "${CRON_PRESENT}" \
  --argjson retention_ok "${RETENTION_OK}" \
  '{
    created_at: $created_at,
    retention_probe: {
      raw_file: $raw_file,
      script_present: $script_present,
      cron_present: $cron_present,
      retention_ok: $retention_ok,
      overall_ok: ($script_present and $cron_present and $retention_ok)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 94 — ODOO Watchdog Retention Probe

## Probe
- raw_file: ${RAW_FILE}
- script_present: ${SCRIPT_PRESENT}
- cron_present: ${CRON_PRESENT}
- retention_ok: ${RETENTION_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] retention probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
