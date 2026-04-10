#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="backups/postgres"
OUT_FILE="${OUT_DIR}/jarvis_postgres_${STAMP}.sql.gz"

mkdir -p "${OUT_DIR}"

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
  echo "[ERRO] PG_PASSWORD/POSTGRES_PASSWORD nao definida"
  exit 1
fi

docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${OUT_FILE}"

echo "[OK] backup postgres criado em ${OUT_FILE}"
ls -lh "${OUT_FILE}"
