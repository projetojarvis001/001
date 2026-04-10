#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/backup_run_${TS}.txt"
OUT_JSON="logs/executive/phase88_odoo_backup_run_${TS}.json"
OUT_MD="docs/generated/phase88_odoo_backup_run_${TS}.md"

DB="${ODOO_DB}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BACKUP_DIR=/home/${ODOO_SSH_USER}/backup_odoo_phase88_${TS}
mkdir -p \${BACKUP_DIR}

echo '===== BACKUP DIR ====='
echo \${BACKUP_DIR}

echo
echo '===== DB DUMP ====='
PGPASSWORD='odoowps' pg_dump -U odoo -h localhost -p 5432 -d '${DB}' -Fc -f \${BACKUP_DIR}/db_${DB}_${TS}.dump
ls -lh \${BACKUP_DIR}/db_${DB}_${TS}.dump
sha256sum \${BACKUP_DIR}/db_${DB}_${TS}.dump

echo
echo '===== ODOO CONF ====='
echo '${ODOO_SSH_PASS}' | sudo -S cp /etc/odoo.conf \${BACKUP_DIR}/odoo.conf
ls -lh \${BACKUP_DIR}/odoo.conf
sha256sum \${BACKUP_DIR}/odoo.conf

echo
echo '===== NGINX CONF ====='
if [ -f /etc/nginx/sites-available/odoo_phase86d ]; then
  echo '${ODOO_SSH_PASS}' | sudo -S cp /etc/nginx/sites-available/odoo_phase86d \${BACKUP_DIR}/nginx_odoo.conf
elif [ -f /etc/nginx/sites-available/odoo_phase86b ]; then
  echo '${ODOO_SSH_PASS}' | sudo -S cp /etc/nginx/sites-available/odoo_phase86b \${BACKUP_DIR}/nginx_odoo.conf
else
  echo '${ODOO_SSH_PASS}' | sudo -S sh -c 'echo missing > /tmp/nginx_odoo.conf'
  mv /tmp/nginx_odoo.conf \${BACKUP_DIR}/nginx_odoo.conf
fi
ls -lh \${BACKUP_DIR}/nginx_odoo.conf
sha256sum \${BACKUP_DIR}/nginx_odoo.conf

echo
echo '===== FILE LIST ====='
find \${BACKUP_DIR} -maxdepth 1 -type f | sort
" > "${RAW_FILE}"

BACKUP_DIR="$(awk '/===== BACKUP DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
DB_DUMP_FILE="$(grep -Eo '/home/[^ ]+db_'"${DB}"'_[0-9-]+\.dump' "${RAW_FILE}" | head -n 1 | tr -d '\r' || true)"
ODOO_CONF_FILE="$(grep -Eo '/home/[^ ]+/odoo\.conf' "${RAW_FILE}" | head -n 1 | tr -d '\r' || true)"
NGINX_CONF_FILE="$(grep -Eo '/home/[^ ]+/nginx_odoo\.conf' "${RAW_FILE}" | head -n 1 | tr -d '\r' || true)"

DB_DUMP_OK=false
ODOO_CONF_OK=false
NGINX_CONF_OK=false

[ -n "${DB_DUMP_FILE}" ] && DB_DUMP_OK=true || true
[ -n "${ODOO_CONF_FILE}" ] && ODOO_CONF_OK=true || true
[ -n "${NGINX_CONF_FILE}" ] && NGINX_CONF_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg backup_dir "${BACKUP_DIR}" \
  --arg db_dump_file "${DB_DUMP_FILE}" \
  --arg odoo_conf_file "${ODOO_CONF_FILE}" \
  --arg nginx_conf_file "${NGINX_CONF_FILE}" \
  --argjson db_dump_ok "${DB_DUMP_OK}" \
  --argjson odoo_conf_ok "${ODOO_CONF_OK}" \
  --argjson nginx_conf_ok "${NGINX_CONF_OK}" \
  '{
    created_at: $created_at,
    backup_run: {
      raw_file: $raw_file,
      backup_dir: $backup_dir,
      db_dump_file: $db_dump_file,
      odoo_conf_file: $odoo_conf_file,
      nginx_conf_file: $nginx_conf_file,
      db_dump_ok: $db_dump_ok,
      odoo_conf_ok: $odoo_conf_ok,
      nginx_conf_ok: $nginx_conf_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 88 — ODOO Backup Run

## Backup
- backup_dir: ${BACKUP_DIR}
- db_dump_file: ${DB_DUMP_FILE}
- odoo_conf_file: ${ODOO_CONF_FILE}
- nginx_conf_file: ${NGINX_CONF_FILE}
- db_dump_ok: ${DB_DUMP_OK}
- odoo_conf_ok: ${ODOO_CONF_OK}
- nginx_conf_ok: ${NGINX_CONF_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] backup run gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
