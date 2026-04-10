#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um backup .sql.gz valido"
  exit 1
fi

if [ "${CONFIRM_RESTORE}" != "YES" ]; then
  echo "[ERRO] restore bloqueado. Use: CONFIRM_RESTORE=YES ./scripts/restore_postgres.sh <arquivo>"
  exit 1
fi

if [ -f .env ]; then
  export $(grep -E '^(POSTGRES_DB|POSTGRES_USER|POSTGRES_PASSWORD)=' .env | xargs)
fi

DB_NAME="${POSTGRES_DB:-jarvis}"
DB_USER="${POSTGRES_USER:-jarvis_admin}"
DB_PASS="${POSTGRES_PASSWORD:-}"

if [ -z "${DB_PASS}" ]; then
  echo "[ERRO] POSTGRES_PASSWORD nao definida"
  exit 1
fi

gunzip -c "${INPUT_FILE}" | docker exec -i -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d "${DB_NAME}"

echo "[OK] restore postgres concluido a partir de ${INPUT_FILE}"
