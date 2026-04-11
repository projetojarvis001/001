#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase98_watchdog_restore_manifest_${TS}.txt"
OUT_JSON="logs/executive/phase98_odoo_watchdog_restore_manifest_${TS}.json"
OUT_MD="docs/generated/phase98_odoo_watchdog_restore_manifest_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
BACKUP_DIR=\"\${BASE_DIR}/backup_phase98_${TS}\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"
ENV_FILE=\"\${BASE_DIR}/alert.env\"
RETENTION_FILE=\"\${BASE_DIR}/retention.sh\"
CRON_FILE=\"\${BACKUP_DIR}/crontab.txt\"

mkdir -p \"\${BACKUP_DIR}\"

cp \"\${SEND_FILE}\" \"\${BACKUP_DIR}/send_alert.sh\"
cp \"\${ENV_FILE}\" \"\${BACKUP_DIR}/alert.env\"
cp \"\${RETENTION_FILE}\" \"\${BACKUP_DIR}/retention.sh\"
crontab -l > \"\${CRON_FILE}\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== BACKUP DIR ====='
echo \"\${BACKUP_DIR}\"
echo
echo '===== FILES ====='
ls -l \"\${BACKUP_DIR}\"
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
BACKUP_DIR="$(awk '/===== BACKUP DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

SEND_OK=false
ENV_OK=false
RETENTION_OK=false
CRON_OK=false

grep -q 'send_alert.sh' "${RAW_FILE}" && SEND_OK=true || true
grep -q 'alert.env' "${RAW_FILE}" && ENV_OK=true || true
grep -q 'retention.sh' "${RAW_FILE}" && RETENTION_OK=true || true
grep -q 'crontab.txt' "${RAW_FILE}" && CRON_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --arg backup_dir "${BACKUP_DIR}" \
  --argjson send_ok "${SEND_OK}" \
  --argjson env_ok "${ENV_OK}" \
  --argjson retention_ok "${RETENTION_OK}" \
  --argjson cron_ok "${CRON_OK}" \
  '{
    created_at: $created_at,
    restore_manifest: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      backup_dir: $backup_dir,
      send_ok: $send_ok,
      env_ok: $env_ok,
      retention_ok: $retention_ok,
      cron_ok: $cron_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 98 — ODOO Watchdog Restore Manifest

## Manifest
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- backup_dir: ${BACKUP_DIR}
- send_ok: ${SEND_OK}
- env_ok: ${ENV_OK}
- retention_ok: ${RETENTION_OK}
- cron_ok: ${CRON_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] restore manifest gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
