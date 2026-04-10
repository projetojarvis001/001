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

docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${TEMP_DB};"

echo "[OK] base temporaria removida: ${TEMP_DB}"
