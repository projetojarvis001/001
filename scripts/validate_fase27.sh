#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

TEMP_DB="jarvis_restore_test"

echo "===== VALIDATE FASE 27 ====="

echo
echo "===== BACKUP FRESCO ====="
./scripts/backup_postgres.sh
LATEST_DB=$(ls -1t backups/postgres/*.sql.gz | head -n 1)
test -f "${LATEST_DB}"
echo "[OK] backup selecionado: ${LATEST_DB}"

echo
echo "===== RESTORE TEMPORARIO ====="
./scripts/restore_postgres_temp.sh "${LATEST_DB}" "${TEMP_DB}"

echo
echo "===== CHECK RESTORE ====="
./scripts/check_postgres_temp_restore.sh "${TEMP_DB}"

echo
echo "===== DROP TEMP DB ====="
./scripts/drop_postgres_temp_db.sh "${TEMP_DB}"

echo
echo "===== CHECK REMOCAO ====="
DB_STILL_EXISTS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='${TEMP_DB}';" 2>/dev/null || true)
if [ "${DB_STILL_EXISTS}" = "1" ]; then
  echo "[ERRO] base temporaria ainda existe"
  exit 1
fi
echo "[OK] limpeza da base temporaria validada"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase26.sh

echo
echo "[OK] fase 27 validada"
