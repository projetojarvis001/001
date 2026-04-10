#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

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

PING=$(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" PING | tr -d '\r')
KEYS=$(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" DBSIZE | tr -d '\r')

echo "===== REDIS STATE ====="
echo "PING=${PING}"
echo "KEYS=${KEYS}"

if [ "${PING}" != "PONG" ]; then
  echo "[ERRO] redis nao respondeu PONG"
  exit 1
fi

echo "[OK] redis operacional"
