#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 25 ====="

echo
echo "===== PRECHECK ====="
test -f .env
echo "[OK] .env presente"

echo
echo "===== BACKUP POSTGRES ====="
./scripts/backup_postgres.sh
LATEST_DB=$(ls -1t backups/postgres/*.sql.gz | head -n 1)
test -f "${LATEST_DB}"
echo "[OK] backup postgres: ${LATEST_DB}"

echo
echo "===== BACKUP ENV ====="
./scripts/backup_env_secure.sh
LATEST_ENV=$(ls -1t backups/env/*.bak | head -n 1)
test -f "${LATEST_ENV}"
echo "[OK] backup env: ${LATEST_ENV}"

echo
echo "===== TESTE RESTORE ENV ====="
cp .env ".env.validate.$(date +%Y%m%d-%H%M%S).bak"
./scripts/restore_env_secure.sh "${LATEST_ENV}"
test -f .env
echo "[OK] restore do .env validado"

echo
echo "===== TESTE BLOQUEIO RESTORE POSTGRES ====="
if ./scripts/restore_postgres.sh "${LATEST_DB}" 2>/tmp/restore_pg_block.err; then
  echo "[ERRO] restore do postgres executou sem confirmacao"
  exit 1
else
  grep -q "restore bloqueado" /tmp/restore_pg_block.err && echo "[OK] restore do postgres protegido"
fi

echo
echo "===== LISTAGEM ====="
./scripts/list_sensitive_backups.sh

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase24.sh

echo
echo "[OK] fase 25 validada"
