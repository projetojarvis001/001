#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 15 ====="

echo
echo "===== RECORD HISTORY ====="
./scripts/record_daily_stack_history.sh >/dev/null
echo "[OK] historico gravado"

echo
echo "===== STACK HISTORY ====="
curl -fsS http://127.0.0.1:3000/stack/history | jq .

echo
echo "===== CHECK HISTORY ====="
curl -fsS http://127.0.0.1:3000/stack/history > /tmp/stack_history_f15.json
jq -e '.ok == true' /tmp/stack_history_f15.json >/dev/null
jq -e '.history != null' /tmp/stack_history_f15.json >/dev/null
jq -e '.summary.days_7 != null' /tmp/stack_history_f15.json >/dev/null
jq -e '.summary.days_7.trend != null' /tmp/stack_history_f15.json >/dev/null
echo "[OK] endpoint /stack/history consistente"

echo
echo "===== DASHBOARD ====="
docker exec jarvis-jarvis-core-1 sh -lc 'grep -q "/stack/history" /app/dashboard/index.html' && echo "[OK] dashboard ligado em /stack/history"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase14.sh

echo
echo "[OK] fase 15 validada"
