#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase97_watchdog_drift_probe_${TS}.txt"
OUT_JSON="logs/executive/phase97_odoo_watchdog_drift_probe_${TS}.json"
OUT_MD="docs/generated/phase97_odoo_watchdog_drift_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

BASELINE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_baseline_*.json 2>/dev/null | head -n 1 || true)"
EXPECTED_SEND_SHA="$(jq -r '.drift_baseline.send_sha // ""' "${BASELINE_FILE}")"
EXPECTED_ENV_SHA="$(jq -r '.drift_baseline.env_sha // ""' "${BASELINE_FILE}")"
EXPECTED_RETENTION_SHA="$(jq -r '.drift_baseline.retention_sha // ""' "${BASELINE_FILE}")"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"
RETENTION_FILE=\"\${BASE_DIR}/retention.sh\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"
ENV_FILE=\"\${BASE_DIR}/alert.env\"
STAMP_FILE=\"\${LOG_DIR}/last_run.ok\"

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
" > "${RAW_FILE}" 2>&1

CURRENT_SEND_SHA="$(awk '/===== SHA SEND =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_ENV_SHA="$(awk '/===== SHA ENV =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_RETENTION_SHA="$(awk '/===== SHA RETENTION =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

SEND_MATCH=false
ENV_MATCH=false
RETENTION_MATCH=false
CRON_WATCHDOG=false
CRON_RETENTION=false
STAMP_PRESENT=false

[ "${CURRENT_SEND_SHA}" = "${EXPECTED_SEND_SHA}" ] && SEND_MATCH=true || true
[ "${CURRENT_ENV_SHA}" = "${EXPECTED_ENV_SHA}" ] && ENV_MATCH=true || true
[ "${CURRENT_RETENTION_SHA}" = "${EXPECTED_RETENTION_SHA}" ] && RETENTION_MATCH=true || true
grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_WATCHDOG=true || true
grep -q 'retention.sh' "${RAW_FILE}" && CRON_RETENTION=true || true
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "${RAW_FILE}" && STAMP_PRESENT=true || true

OVERALL_OK=false
if [ "${SEND_MATCH}" = "true" ] && [ "${ENV_MATCH}" = "true" ] && [ "${RETENTION_MATCH}" = "true" ] && [ "${CRON_WATCHDOG}" = "true" ] && [ "${CRON_RETENTION}" = "true" ] && [ "${STAMP_PRESENT}" = "true" ]; then
  OVERALL_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg baseline_file "${BASELINE_FILE}" \
  --arg current_send_sha "${CURRENT_SEND_SHA}" \
  --arg current_env_sha "${CURRENT_ENV_SHA}" \
  --arg current_retention_sha "${CURRENT_RETENTION_SHA}" \
  --argjson send_match "${SEND_MATCH}" \
  --argjson env_match "${ENV_MATCH}" \
  --argjson retention_match "${RETENTION_MATCH}" \
  --argjson cron_watchdog "${CRON_WATCHDOG}" \
  --argjson cron_retention "${CRON_RETENTION}" \
  --argjson stamp_present "${STAMP_PRESENT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    drift_probe: {
      raw_file: $raw_file,
      baseline_file: $baseline_file,
      current_send_sha: $current_send_sha,
      current_env_sha: $current_env_sha,
      current_retention_sha: $current_retention_sha,
      send_match: $send_match,
      env_match: $env_match,
      retention_match: $retention_match,
      cron_watchdog: $cron_watchdog,
      cron_retention: $cron_retention,
      stamp_present: $stamp_present,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 97 — ODOO Watchdog Drift Probe

## Probe
- raw_file: ${RAW_FILE}
- baseline_file: ${BASELINE_FILE}
- current_send_sha: ${CURRENT_SEND_SHA}
- current_env_sha: ${CURRENT_ENV_SHA}
- current_retention_sha: ${CURRENT_RETENTION_SHA}
- send_match: ${SEND_MATCH}
- env_match: ${ENV_MATCH}
- retention_match: ${RETENTION_MATCH}
- cron_watchdog: ${CRON_WATCHDOG}
- cron_retention: ${CRON_RETENTION}
- stamp_present: ${STAMP_PRESENT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
