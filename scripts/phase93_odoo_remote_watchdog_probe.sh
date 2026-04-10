#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase93_remote_watchdog_probe_${TS}.txt"
OUT_JSON="logs/executive/phase93_odoo_remote_watchdog_probe_${TS}.json"
OUT_MD="docs/generated/phase93_odoo_remote_watchdog_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
echo '===== CRONTAB ====='
crontab -l || true
echo
echo '===== LOG FILES ====='
ls -1 \"\${BASE_DIR}/logs\" || true
echo
echo '===== LAST JSON ====='
cat \"\${BASE_DIR}/logs/last_run.json\" || true
echo
echo '===== LAST STAMP ====='
cat \"\${BASE_DIR}/logs/last_run.ok\" || true
" > "${RAW_FILE}" 2>&1

CRON_OK=false
LAST_JSON_OK=false
LAST_STAMP_OK=false
OVERALL_OK=false

grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_OK=true || true
grep -q 'last_run.json' "${RAW_FILE}" && LAST_JSON_OK=true || true
grep -q 'last_run.ok' "${RAW_FILE}" && LAST_STAMP_OK=true || true
grep -q '"overall_ok": true' "${RAW_FILE}" && OVERALL_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson cron_ok "${CRON_OK}" \
  --argjson last_json_ok "${LAST_JSON_OK}" \
  --argjson last_stamp_ok "${LAST_STAMP_OK}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    remote_watchdog_probe: {
      raw_file: $raw_file,
      cron_ok: $cron_ok,
      last_json_ok: $last_json_ok,
      last_stamp_ok: $last_stamp_ok,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 93 — ODOO Remote Watchdog Probe

## Probe
- raw_file: ${RAW_FILE}
- cron_ok: ${CRON_OK}
- last_json_ok: ${LAST_JSON_OK}
- last_stamp_ok: ${LAST_STAMP_OK}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] remote watchdog probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
