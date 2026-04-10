#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase88_odoo_restore_manifest_${TS}.json"
OUT_MD="docs/generated/phase88_odoo_restore_manifest_${TS}.md"

RUN_FILE="$(ls -1t logs/executive/phase88_odoo_backup_run_*.json 2>/dev/null | head -n 1 || true)"

BACKUP_DIR="$(jq -r '.backup_run.backup_dir // ""' "${RUN_FILE}")"
DB_DUMP_FILE="$(jq -r '.backup_run.db_dump_file // ""' "${RUN_FILE}")"
ODOO_CONF_FILE="$(jq -r '.backup_run.odoo_conf_file // ""' "${RUN_FILE}")"
NGINX_CONF_FILE="$(jq -r '.backup_run.nginx_conf_file // ""' "${RUN_FILE}")"
DB="${ODOO_DB}"

RESTORE_READY=false
if [ -n "${DB_DUMP_FILE}" ] && [ -n "${ODOO_CONF_FILE}" ] && [ -n "${NGINX_CONF_FILE}" ]; then
  RESTORE_READY=true
fi

DB_RESTORE_CMD="dropdb -U odoo -h localhost -p 5432 --if-exists ${DB} && createdb -U odoo -h localhost -p 5432 ${DB} && pg_restore -U odoo -h localhost -p 5432 -d ${DB} '${DB_DUMP_FILE}'"
CONF_RESTORE_CMD="sudo cp '${ODOO_CONF_FILE}' /etc/odoo.conf && sudo systemctl restart odoo"
NGINX_RESTORE_CMD="sudo cp '${NGINX_CONF_FILE}' /etc/nginx/sites-available/odoo_phase86d && sudo nginx -t && sudo systemctl restart nginx"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg run_file "${RUN_FILE}" \
  --arg backup_dir "${BACKUP_DIR}" \
  --arg db_dump_file "${DB_DUMP_FILE}" \
  --arg odoo_conf_file "${ODOO_CONF_FILE}" \
  --arg nginx_conf_file "${NGINX_CONF_FILE}" \
  --arg db_restore_cmd "${DB_RESTORE_CMD}" \
  --arg conf_restore_cmd "${CONF_RESTORE_CMD}" \
  --arg nginx_restore_cmd "${NGINX_RESTORE_CMD}" \
  --argjson restore_ready "${RESTORE_READY}" \
  '{
    created_at: $created_at,
    restore_manifest: {
      run_file: $run_file,
      backup_dir: $backup_dir,
      db_dump_file: $db_dump_file,
      odoo_conf_file: $odoo_conf_file,
      nginx_conf_file: $nginx_conf_file,
      db_restore_cmd: $db_restore_cmd,
      conf_restore_cmd: $conf_restore_cmd,
      nginx_restore_cmd: $nginx_restore_cmd,
      restore_ready: $restore_ready
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 88 — ODOO Restore Manifest

## Restore
- backup_dir: ${BACKUP_DIR}
- db_dump_file: ${DB_DUMP_FILE}
- odoo_conf_file: ${ODOO_CONF_FILE}
- nginx_conf_file: ${NGINX_CONF_FILE}
- restore_ready: ${RESTORE_READY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] restore manifest gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
