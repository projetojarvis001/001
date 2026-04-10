#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 17 ====="

echo
echo "===== RECORD HISTORY ====="
./scripts/record_daily_stack_history.sh >/dev/null
echo "[OK] historico atualizado"

echo
echo "===== EXPORT CSV ====="
./scripts/export_stack_history_csv.sh
test -f logs/history/stack_daily_history.csv
echo "[OK] csv existe"

echo
echo "===== HISTORY EXPORT ENDPOINT ====="
curl -fsS http://127.0.0.1:3000/stack/history/export | jq .

echo
echo "===== CHECK EXPORT ENDPOINT ====="
curl -fsS http://127.0.0.1:3000/stack/history/export > /tmp/stack_history_export_f17.json
jq -e '.ok == true' /tmp/stack_history_export_f17.json >/dev/null
jq -e '.json_path != null' /tmp/stack_history_export_f17.json >/dev/null
jq -e '.csv_path != null' /tmp/stack_history_export_f17.json >/dev/null
jq -e '.records != null' /tmp/stack_history_export_f17.json >/dev/null
echo "[OK] endpoint /stack/history/export consistente"

echo
echo "===== CSV HEADER ====="
head -n 1 logs/history/stack_daily_history.csv
grep -q 'date' logs/history/stack_daily_history.csv && echo "[OK] cabecalho CSV ok"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase16.sh

echo
echo "[OK] fase 17 validada"
