#!/usr/bin/env bash
set -e

echo "===== SNAPSHOT ====="
./scripts/snapshot_stack_health.sh

echo
echo "===== ALERT CHECK ====="
./scripts/check_stack_alert.sh

echo
echo "===== OPS REPORT ====="
./scripts/ops_report_vision.sh

echo
echo "[OK] rotina diaria concluida"
