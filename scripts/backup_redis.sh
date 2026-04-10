#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="backups/redis"
OUT_FILE="${OUT_DIR}/redis_dump_${STAMP}.rdb"

mkdir -p "${OUT_DIR}"

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

echo "===== REDIS BGSAVE ====="
LASTSAVE_BEFORE="$("${REDIS_CLI[@]}" LASTSAVE | tr -d '\r')"

# Dispara snapshot; se já estiver em progresso, seguimos para espera
BGSAVE_OUT="$("${REDIS_CLI[@]}" BGSAVE 2>&1 || true)"
echo "${BGSAVE_OUT}" | grep -Eq 'Background saving started|already in progress' || {
  echo "[ERRO] falha ao iniciar BGSAVE"
  echo "${BGSAVE_OUT}"
  exit 1
}

UPDATED="false"
for i in $(seq 1 30); do
  LASTSAVE_AFTER="$("${REDIS_CLI[@]}" LASTSAVE | tr -d '\r')"
  if [ -n "${LASTSAVE_AFTER}" ] && [ "${LASTSAVE_AFTER}" != "${LASTSAVE_BEFORE}" ]; then
    UPDATED="true"
    break
  fi
  sleep 1
done

if [ "${UPDATED}" != "true" ]; then
  echo "[ERRO] snapshot redis nao confirmou novo LASTSAVE"
  exit 1
fi

docker cp redis:/data/dump.rdb "${OUT_FILE}"

if [ ! -f "${OUT_FILE}" ]; then
  echo "[ERRO] backup redis nao foi gerado"
  exit 1
fi

echo "[OK] backup redis criado em ${OUT_FILE}"
ls -lh "${OUT_FILE}"
