#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== SNAPSHOT ====="
./scripts/snapshot_stack_health.sh

echo
echo "===== HISTORICO ====="
./scripts/record_daily_stack_history.sh >/dev/null
echo "[OK] historico diario atualizado"

echo
echo "===== EXPORT CSV ====="
./scripts/export_stack_history_csv.sh >/dev/null
echo "[OK] csv diario atualizado"

echo
echo "===== ALERT CHECK ====="
./scripts/check_stack_alert.sh

echo
echo "===== OPS REPORT ====="
./scripts/ops_report_vision.sh

echo
echo "===== RESUMO DIARIO ====="
./scripts/send_daily_stack_summary.sh

echo
echo "[OK] rotina diaria concluida"
