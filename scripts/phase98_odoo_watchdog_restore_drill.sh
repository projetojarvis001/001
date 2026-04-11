#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase98_watchdog_restore_drill_${TS}.txt"
OUT_JSON="logs/executive/phase98_odoo_watchdog_restore_drill_${TS}.json"
OUT_MD="docs/generated/phase98_odoo_watchdog_restore_drill_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

MANIFEST_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"
BACKUP_DIR="$(jq -r '.restore_manifest.backup_dir // ""' "${MANIFEST_FILE}")"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"
ENV_FILE=\"\${BASE_DIR}/alert.env\"
RETENTION_FILE=\"\${BASE_DIR}/retention.sh\"

cp \"\${SEND_FILE}\" \"\${SEND_FILE}.tmp.phase98\"
cp \"\${ENV_FILE}\" \"\${ENV_FILE}.tmp.phase98\"
cp \"\${RETENTION_FILE}\" \"\${RETENTION_FILE}.tmp.phase98\"

printf '# broken\n' > \"\${SEND_FILE}\"
printf '# broken\n' > \"\${RETENTION_FILE}\"
printf 'BROKEN=1\n' > \"\${ENV_FILE}\"

cp '${BACKUP_DIR}/send_alert.sh' \"\${SEND_FILE}\"
cp '${BACKUP_DIR}/alert.env' \"\${ENV_FILE}\"
cp '${BACKUP_DIR}/retention.sh' \"\${RETENTION_FILE}\"
crontab '${BACKUP_DIR}/crontab.txt'

chmod 700 \"\${SEND_FILE}\"
chmod 700 \"\${RETENTION_FILE}\"
chmod 600 \"\${ENV_FILE}\"

rm -f \"\${SEND_FILE}.tmp.phase98\" \"\${ENV_FILE}.tmp.phase98\" \"\${RETENTION_FILE}.tmp.phase98\"

echo '===== SEND SHA ====='
sha256sum \"\${SEND_FILE}\"
echo
echo '===== ENV SHA ====='
sha256sum \"\${ENV_FILE}\"
echo
echo '===== RETENTION SHA ====='
sha256sum \"\${RETENTION_FILE}\"
echo
echo '===== CRONTAB ====='
crontab -l
" > "${RAW_FILE}" 2>&1

BASELINE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_baseline_*.json 2>/dev/null | head -n 1 || true)"
EXPECTED_SEND_SHA="$(jq -r '.drift_baseline.send_sha // ""' "${BASELINE_FILE}")"
EXPECTED_ENV_SHA="$(jq -r '.drift_baseline.env_sha // ""' "${BASELINE_FILE}")"
EXPECTED_RETENTION_SHA="$(jq -r '.drift_baseline.retention_sha // ""' "${BASELINE_FILE}")"

CURRENT_SEND_SHA="$(awk '/===== SEND SHA =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_ENV_SHA="$(awk '/===== ENV SHA =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_RETENTION_SHA="$(awk '/===== RETENTION SHA =====/{getline; print $1; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

SEND_RESTORED=false
ENV_RESTORED=false
RETENTION_RESTORED=false
CRON_RESTORED=false

[ "${CURRENT_SEND_SHA}" = "${EXPECTED_SEND_SHA}" ] && SEND_RESTORED=true || true
[ "${CURRENT_ENV_SHA}" = "${EXPECTED_ENV_SHA}" ] && ENV_RESTORED=true || true
[ "${CURRENT_RETENTION_SHA}" = "${EXPECTED_RETENTION_SHA}" ] && RETENTION_RESTORED=true || true
grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_RESTORED=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg baseline_file "${BASELINE_FILE}" \
  --arg current_send_sha "${CURRENT_SEND_SHA}" \
  --arg current_env_sha "${CURRENT_ENV_SHA}" \
  --arg current_retention_sha "${CURRENT_RETENTION_SHA}" \
  --argjson send_restored "${SEND_RESTORED}" \
  --argjson env_restored "${ENV_RESTORED}" \
  --argjson retention_restored "${RETENTION_RESTORED}" \
  --argjson cron_restored "${CRON_RESTORED}" \
  '{
    created_at: $created_at,
    restore_drill: {
      raw_file: $raw_file,
      manifest_file: $manifest_file,
      baseline_file: $baseline_file,
      current_send_sha: $current_send_sha,
      current_env_sha: $current_env_sha,
      current_retention_sha: $current_retention_sha,
      send_restored: $send_restored,
      env_restored: $env_restored,
      retention_restored: $retention_restored,
      cron_restored: $cron_restored,
      overall_ok: ($send_restored and $env_restored and $retention_restored and $cron_restored)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 98 — ODOO Watchdog Restore Drill

## Drill
- raw_file: ${RAW_FILE}
- manifest_file: ${MANIFEST_FILE}
- baseline_file: ${BASELINE_FILE}
- current_send_sha: ${CURRENT_SEND_SHA}
- current_env_sha: ${CURRENT_ENV_SHA}
- current_retention_sha: ${CURRENT_RETENTION_SHA}
- send_restored: ${SEND_RESTORED}
- env_restored: ${ENV_RESTORED}
- retention_restored: ${RETENTION_RESTORED}
- cron_restored: ${CRON_RESTORED}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] restore drill gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
