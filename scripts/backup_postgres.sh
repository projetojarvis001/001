#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="backups/postgres"
OUT_FILE="${OUT_DIR}/jarvis_postgres_${STAMP}.sql.gz"

mkdir -p "${OUT_DIR}"

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
  echo "[ERRO] POSTGRES_PASSWORD nao definida"
  exit 1
fi

docker exec -e PGPASSWORD="${DB_PASS}" jarvis-postgres-1 \
  pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${OUT_FILE}"

echo "[OK] backup postgres criado em ${OUT_FILE}"
ls -lh "${OUT_FILE}"
