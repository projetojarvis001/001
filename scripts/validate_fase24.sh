#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 24 ====="

echo
echo "===== PRECHECK ====="
test -d logs/state
test -d logs/history
echo "[OK] diretorios operacionais existem"

echo
echo "===== BACKUP ====="
./scripts/backup_operational_state.sh
LATEST_BACKUP=$(ls -1t backups/operational_state/*.tar.gz | head -n 1)
echo "[OK] ultimo backup: ${LATEST_BACKUP}"

echo
echo "===== SABOTAGEM CONTROLADA ====="
mkdir -p logs/state logs/history
echo '{"corrompido":true}' > logs/state/stack_metrics.json
echo '[]' > logs/history/stack_daily_history.json
echo "[OK] sabotagem aplicada"

echo
echo "===== RESTORE ====="
./scripts/restore_operational_state.sh "${LATEST_BACKUP}"

echo
echo "===== CHECK RESTORE ====="
test -f logs/state/stack_metrics.json
test -f logs/history/stack_daily_history.json
jq empty logs/state/stack_metrics.json >/dev/null 2>&1
jq empty logs/history/stack_daily_history.json >/dev/null 2>&1
echo "[OK] restore integrou arquivos validos"

echo
echo "===== LISTAGEM ====="
./scripts/list_operational_backups.sh

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase23.sh

echo
echo "[OK] fase 24 validada"
