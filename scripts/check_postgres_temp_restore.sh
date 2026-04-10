#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

TEMP_DB="${1:-jarvis_restore_test}"
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
  echo "[ERRO] PG_PASSWORD/POSTGRES_PASSWORD nao definida"
  exit 1
fi

echo "===== CHECK TEMP DB ====="

DB_EXISTS=$(docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='${TEMP_DB}';")

if [ "${DB_EXISTS}" != "1" ]; then
  echo "[ERRO] base temporaria nao existe: ${TEMP_DB}"
  exit 1
fi

TABLE_COUNT=$(docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d "${TEMP_DB}" -Atqc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")

echo "TEMP_DB=${TEMP_DB}"
echo "TABLE_COUNT=${TABLE_COUNT}"

if [ -z "${TABLE_COUNT}" ] || [ "${TABLE_COUNT}" = "0" ]; then
  echo "[ERRO] restore temporario sem tabelas publicas"
  exit 1
fi

echo "[OK] restore temporario consistente"
