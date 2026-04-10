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

DB_NAME="jarvis_db"
DB_USER="jarvis_admin"
DB_PASS=""

if [ -f .env ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      PG_PASSWORD) DB_PASS="$value" ;;
    esac
  done < <(grep -E '^(PG_PASSWORD)=' .env)
fi

if [ -z "${DB_PASS}" ]; then
  DB_PASS="$(docker inspect jarvis-postgres-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^POSTGRES_PASSWORD=' | head -n 1 | cut -d= -f2-)"
fi

if [ -z "${DB_PASS}" ]; then
  echo "[ERRO] PG_PASSWORD/POSTGRES_PASSWORD nao definida" >&2
  exit 1
fi

gunzip -c "${INPUT_FILE}" | docker exec -i -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d "${DB_NAME}"

echo "[OK] restore postgres concluido a partir de ${INPUT_FILE}"
