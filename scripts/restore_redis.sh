#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um backup .rdb valido"
  exit 1
fi

if [ "${CONFIRM_RESTORE}" != "YES" ]; then
  echo "[ERRO] restore bloqueado. Use: CONFIRM_RESTORE=YES ./scripts/restore_redis.sh <arquivo>" >&2
  exit 1
fi

REDIS_PASS=""
if [ -f .env ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      REDIS_PASSWORD) REDIS_PASS="$value" ;;
    esac
  done < <(grep -E '^(REDIS_PASSWORD)=' .env)
fi

if [ -z "${REDIS_PASS}" ]; then
  echo "[ERRO] REDIS_PASSWORD nao definida"
  exit 1
fi

REDIS_CLI=(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}")

REDIS_DIR="$("${REDIS_CLI[@]}" CONFIG GET dir | tail -n 1 | tr -d '\r')"
REDIS_DBFILE="$("${REDIS_CLI[@]}" CONFIG GET dbfilename | tail -n 1 | tr -d '\r')"

if [ -z "${REDIS_DIR}" ] || [ -z "${REDIS_DBFILE}" ]; then
  echo "[ERRO] nao foi possivel descobrir dir/dbfilename do redis"
  exit 1
fi

TARGET_PATH="${REDIS_DIR}/${REDIS_DBFILE}"

echo "===== RESTORE REDIS ====="
echo "TARGET_PATH=${TARGET_PATH}"

echo "===== STOP REDIS ====="
docker stop redis >/dev/null

echo "===== COPY DUMP ====="
docker cp "${INPUT_FILE}" "redis:${TARGET_PATH}"

echo "===== START REDIS ====="
docker start redis >/dev/null

sleep 5

echo "[OK] restore redis concluido a partir de ${INPUT_FILE}"
