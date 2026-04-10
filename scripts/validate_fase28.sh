#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 28 ====="

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

TEST_KEY="fase28:test:key"
TEST_VALUE="ok-$(date +%s)"

echo
echo "===== PRECHECK ====="
./scripts/check_redis_state.sh

echo
echo "===== INJETA CHAVE TESTE ====="
docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" SET "${TEST_KEY}" "${TEST_VALUE}" >/dev/null
BEFORE=$(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" GET "${TEST_KEY}" | tr -d '\r')
echo "TEST_VALUE_BEFORE=${BEFORE}"

echo
echo "===== BACKUP REDIS ====="
./scripts/backup_redis.sh
LATEST_REDIS=$(ls -1t backups/redis/*.rdb | head -n 1)
test -f "${LATEST_REDIS}"
echo "[OK] backup selecionado: ${LATEST_REDIS}"

echo
echo "===== REMOVE CHAVE ====="
docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" DEL "${TEST_KEY}" >/dev/null
AFTER_DEL=$(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" GET "${TEST_KEY}" | tr -d '\r')
[ "${AFTER_DEL}" = "" ] && echo "[OK] chave removida"

echo
echo "===== TESTE BLOQUEIO RESTORE ====="
if ./scripts/restore_redis.sh "${LATEST_REDIS}" 2>/tmp/restore_redis_block.err; then
  echo "[ERRO] restore redis executou sem confirmacao"
  exit 1
else
  grep -q "restore bloqueado" /tmp/restore_redis_block.err && echo "[OK] restore redis protegido"
fi

echo
echo "===== RESTORE REDIS ====="
CONFIRM_RESTORE=YES ./scripts/restore_redis.sh "${LATEST_REDIS}"

echo
echo "===== CHECK POS-RESTORE ====="
./scripts/check_redis_state.sh
AFTER_RESTORE=$(docker exec redis redis-cli --no-auth-warning -a "${REDIS_PASS}" GET "${TEST_KEY}" | tr -d '\r')
echo "TEST_VALUE_AFTER=${AFTER_RESTORE}"

if [ "${AFTER_RESTORE}" != "${TEST_VALUE}" ]; then
  echo "[ERRO] chave de teste nao voltou apos restore"
  exit 1
fi
echo "[OK] chave de teste restaurada com sucesso"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase27.sh

echo
echo "[OK] fase 28 validada"
