#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== CONFIG CONSISTENCY CHECK ====="
date
echo

COMPOSE_FILE="docker-compose.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "[ERRO] docker-compose.yml nao encontrado"
  exit 1
fi

POSTGRES_DB_COMPOSE=$(grep -E 'POSTGRES_DB:' "${COMPOSE_FILE}" | head -n 1 | sed -E 's/.*POSTGRES_DB:[[:space:]]*//')
POSTGRES_USER_COMPOSE=$(grep -E 'POSTGRES_USER:' "${COMPOSE_FILE}" | head -n 1 | sed -E 's/.*POSTGRES_USER:[[:space:]]*//')

DATABASE_URL_CORE=$(grep -E 'DATABASE_URL=' "${COMPOSE_FILE}" | head -n 1 | sed -E 's/.*DATABASE_URL=//')
DB_NAME_URL=$(printf "%s" "${DATABASE_URL_CORE}" | sed -E 's#.*/([^/?"]+)(\?.*)?$#\1#')
DB_USER_URL=$(printf "%s" "${DATABASE_URL_CORE}" | sed -E 's#^[^:]+://([^:]+):.*#\1#')

POSTGRES_DB_RUNTIME=$(docker inspect jarvis-postgres-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^POSTGRES_DB=' | head -n 1 | cut -d= -f2-)
POSTGRES_USER_RUNTIME=$(docker inspect jarvis-postgres-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^POSTGRES_USER=' | head -n 1 | cut -d= -f2-)

STATUS=0

echo "===== COMPOSE ====="
echo "POSTGRES_DB=${POSTGRES_DB_COMPOSE}"
echo "POSTGRES_USER=${POSTGRES_USER_COMPOSE}"
echo

echo "===== CORE URL ====="
echo "DATABASE_URL=${DATABASE_URL_CORE}"
echo "DB_NAME_URL=${DB_NAME_URL}"
echo "DB_USER_URL=${DB_USER_URL}"
echo

echo "===== RUNTIME POSTGRES ====="
echo "POSTGRES_DB=${POSTGRES_DB_RUNTIME}"
echo "POSTGRES_USER=${POSTGRES_USER_RUNTIME}"
echo

if [ "${POSTGRES_DB_COMPOSE}" != "${DB_NAME_URL}" ]; then
  echo "[ERRO] DATABASE_URL aponta para banco diferente do compose"
  STATUS=1
else
  echo "[OK] nome do banco alinhado"
fi

if [ "${POSTGRES_USER_COMPOSE}" != "${DB_USER_URL}" ]; then
  echo "[ERRO] DATABASE_URL aponta para usuario diferente do compose"
  STATUS=1
else
  echo "[OK] usuario do banco alinhado"
fi

if [ "${POSTGRES_DB_COMPOSE}" != "${POSTGRES_DB_RUNTIME}" ]; then
  echo "[ERRO] banco em runtime diverge do compose"
  STATUS=1
else
  echo "[OK] banco em runtime alinhado"
fi

if [ "${POSTGRES_USER_COMPOSE}" != "${POSTGRES_USER_RUNTIME}" ]; then
  echo "[ERRO] usuario em runtime diverge do compose"
  STATUS=1
else
  echo "[OK] usuario em runtime alinhado"
fi

echo
if [ "${STATUS}" -eq 0 ]; then
  echo "[OK] configuracao consistente"
else
  echo "[ALERTA] inconsistencias encontradas"
fi

exit "${STATUS}"
