#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin


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
