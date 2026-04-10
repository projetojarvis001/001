#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um backup .sql.gz valido"
  exit 1
fi

if [ "${CONFIRM_RESTORE}" != "YES" ]; then
  echo "[ERRO] restore bloqueado. Use: CONFIRM_RESTORE=YES ./scripts/restore_postgres.sh <arquivo>" >&2
  exit 1
fi

POSTGRES_DB_VALUE=""
POSTGRES_USER_VALUE=""
POSTGRES_PASSWORD_VALUE=""

if [ -f .env ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      POSTGRES_DB) POSTGRES_DB_VALUE="$value" ;;
      POSTGRES_USER) POSTGRES_USER_VALUE="$value" ;;
      POSTGRES_PASSWORD) POSTGRES_PASSWORD_VALUE="$value" ;;
    esac
  done < <(grep -E '^(POSTGRES_DB|POSTGRES_USER|POSTGRES_PASSWORD)=' .env)
fi

DB_NAME="${POSTGRES_DB_VALUE:-jarvis}"
DB_USER="${POSTGRES_USER_VALUE:-jarvis_admin}"
DB_PASS="${POSTGRES_PASSWORD_VALUE:-}"

if [ -z "${DB_PASS}" ]; then
  echo "[ERRO] POSTGRES_PASSWORD nao definida" >&2
  exit 1
fi

gunzip -c "${INPUT_FILE}" | docker exec -i -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d "${DB_NAME}"

echo "[OK] restore postgres concluido a partir de ${INPUT_FILE}"
