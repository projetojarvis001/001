#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="backups/postgres"
OUT_FILE="${OUT_DIR}/jarvis_postgres_${STAMP}.sql.gz"

mkdir -p "${OUT_DIR}"

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

docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${OUT_FILE}"

echo "[OK] backup postgres criado em ${OUT_FILE}"
ls -lh "${OUT_FILE}"
