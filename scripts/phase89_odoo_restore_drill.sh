#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/restore_drill_${TS}.txt"
OUT_JSON="logs/executive/phase89_odoo_restore_drill_${TS}.json"
OUT_MD="docs/generated/phase89_odoo_restore_drill_${TS}.md"

MANIFEST_FILE="$(ls -1t logs/executive/phase88_odoo_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"
SEED_FILE="$(ls -1t logs/executive/phase89_odoo_drill_seed_*.json 2>/dev/null | head -n 1 || true)"

DB_DUMP_FILE="$(jq -r '.restore_manifest.db_dump_file // ""' "${MANIFEST_FILE}")"
DRILL_DB="$(jq -r '.seed.drill_db // ""' "${SEED_FILE}")"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

echo '===== INPUTS ====='
echo DRILL_DB=${DRILL_DB}
echo DB_DUMP_FILE=${DB_DUMP_FILE}

echo
echo '===== DROP IF EXISTS ====='
PGPASSWORD='odoowps' dropdb -U odoo -h localhost -p 5432 --if-exists '${DRILL_DB}' || true

echo
echo '===== CREATE DRILL DB ====='
PGPASSWORD='odoowps' createdb -U odoo -h localhost -p 5432 '${DRILL_DB}'

echo
echo '===== RESTORE DRILL DB ====='
PGPASSWORD='odoowps' pg_restore -U odoo -h localhost -p 5432 -d '${DRILL_DB}' '${DB_DUMP_FILE}'

echo
echo '===== CHECK TABLE COUNT ====='
PGPASSWORD='odoowps' psql -U odoo -h localhost -p 5432 -d '${DRILL_DB}' -tAc \"select count(*) from information_schema.tables where table_schema='public';\"

echo
echo '===== CHECK USERS ====='
PGPASSWORD='odoowps' psql -U odoo -h localhost -p 5432 -d '${DRILL_DB}' -tAc \"select count(*) from res_users;\"

echo
echo '===== DRILL DB READY ====='
echo '${DRILL_DB}'
" > "${RAW_FILE}"

TABLE_COUNT="$(awk '/===== CHECK TABLE COUNT =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r ' || true)"
USER_COUNT="$(awk '/===== CHECK USERS =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r ' || true)"
DRILL_DB_READY=false

if [ -n "${TABLE_COUNT}" ] && [ "${TABLE_COUNT}" != "0" ] && [ -n "${USER_COUNT}" ] && [ "${USER_COUNT}" != "0" ]; then
  DRILL_DB_READY=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg seed_file "${SEED_FILE}" \
  --arg drill_db "${DRILL_DB}" \
  --arg db_dump_file "${DB_DUMP_FILE}" \
  --arg table_count "${TABLE_COUNT}" \
  --arg user_count "${USER_COUNT}" \
  --argjson drill_db_ready "${DRILL_DB_READY}" \
  '{
    created_at: $created_at,
    restore_drill: {
      raw_file: $raw_file,
      manifest_file: $manifest_file,
      seed_file: $seed_file,
      drill_db: $drill_db,
      db_dump_file: $db_dump_file,
      table_count: ($table_count | tonumber),
      user_count: ($user_count | tonumber),
      drill_db_ready: $drill_db_ready
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 89 — ODOO Restore Drill

## Restore
- drill_db: ${DRILL_DB}
- db_dump_file: ${DB_DUMP_FILE}
- table_count: ${TABLE_COUNT}
- user_count: ${USER_COUNT}
- drill_db_ready: ${DRILL_DB_READY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] restore drill gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
