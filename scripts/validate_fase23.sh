#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 23 ====="

echo
echo "===== RELATORIO ANTES ====="
./scripts/logs_retention_report.sh

echo
echo "===== ROTACAO ====="
./scripts/rotate_logs.sh

echo
echo "===== RELATORIO DEPOIS ====="
./scripts/logs_retention_report.sh

echo
echo "===== CHECK SCRIPTS ====="
test -x scripts/rotate_logs.sh
test -x scripts/logs_retention_report.sh
grep -q "rotate_logs.sh" scripts/run_daily_stack_routine.sh
grep -q "logs_retention_report.sh" scripts/run_daily_stack_routine.sh
echo "[OK] scripts e integracao ok"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase20.sh

echo
echo "[OK] fase 23 validada"
