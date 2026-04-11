#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase97_watchdog_drift_baseline_${TS}.txt"
OUT_JSON="logs/executive/phase97_odoo_watchdog_drift_baseline_${TS}.json"
OUT_MD="docs/generated/phase97_odoo_watchdog_drift_baseline_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"
RETENTION_FILE=\"\${BASE_DIR}/retention.sh\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"
ENV_FILE=\"\${BASE_DIR}/alert.env\"
STAMP_FILE=\"\${LOG_DIR}/last_run.ok\"
LAST_JSON=\"\${LOG_DIR}/last_run.json\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== SHA SEND ====='
sha256sum \"\${SEND_FILE}\" || true
echo
echo '===== SHA ENV ====='
sha256sum \"\${ENV_FILE}\" || true
echo
echo '===== SHA RETENTION ====='
[ -f \"\${RETENTION_FILE}\" ] && sha256sum \"\${RETENTION_FILE}\" || echo 'NO_RETENTION'
echo
echo '===== CRONTAB ====='
crontab -l || true
echo
echo '===== STAMP ====='
[ -f \"\${STAMP_FILE}\" ] && cat \"\${STAMP_FILE}\" || echo 'NO_STAMP'
echo
echo '===== LAST JSON ====='
[ -f \"\${LAST_JSON}\" ] && cat \"\${LAST_JSON}\" || echo 'NO_LAST_JSON'
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
SEND_SHA="$(awk '/===== SHA SEND =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
ENV_SHA="$(awk '/===== SHA ENV =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
RETENTION_SHA="$(awk '/===== SHA RETENTION =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

CRON_WATCHDOG=false
CRON_RETENTION=false
STAMP_PRESENT=false
LAST_JSON_OK=false

grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_WATCHDOG=true || true
grep -q 'retention.sh' "${RAW_FILE}" && CRON_RETENTION=true || true
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "${RAW_FILE}" && STAMP_PRESENT=true || true
grep -q '"overall_ok": true' "${RAW_FILE}" && LAST_JSON_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --arg send_sha "${SEND_SHA}" \
  --arg env_sha "${ENV_SHA}" \
  --arg retention_sha "${RETENTION_SHA}" \
  --argjson cron_watchdog "${CRON_WATCHDOG}" \
  --argjson cron_retention "${CRON_RETENTION}" \
  --argjson stamp_present "${STAMP_PRESENT}" \
  --argjson last_json_ok "${LAST_JSON_OK}" \
  '{
    created_at: $created_at,
    drift_baseline: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      send_sha: $send_sha,
      env_sha: $env_sha,
      retention_sha: $retention_sha,
      cron_watchdog: $cron_watchdog,
      cron_retention: $cron_retention,
      stamp_present: $stamp_present,
      last_json_ok: $last_json_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 97 — ODOO Watchdog Drift Baseline

## Baseline
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- send_sha: ${SEND_SHA}
- env_sha: ${ENV_SHA}
- retention_sha: ${RETENTION_SHA}
- cron_watchdog: ${CRON_WATCHDOG}
- cron_retention: ${CRON_RETENTION}
- stamp_present: ${STAMP_PRESENT}
- last_json_ok: ${LAST_JSON_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift baseline gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
