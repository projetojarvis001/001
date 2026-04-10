#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 16 ====="

echo
echo "===== HISTORY COMPACT ====="
curl -fsS http://127.0.0.1:3000/stack/history/compact | jq .

echo
echo "===== CHECK HISTORY COMPACT ====="
curl -fsS http://127.0.0.1:3000/stack/history/compact > /tmp/stack_history_compact_f16.json
jq -e '.ok == true' /tmp/stack_history_compact_f16.json >/dev/null
jq -e '.summary.executive_status != null' /tmp/stack_history_compact_f16.json >/dev/null
jq -e '.summary.trend_7d != null' /tmp/stack_history_compact_f16.json >/dev/null
jq -e '.series_7d != null' /tmp/stack_history_compact_f16.json >/dev/null
echo "[OK] endpoint /stack/history/compact consistente"

echo
echo "===== DASHBOARD ====="
docker exec jarvis-jarvis-core-1 sh -lc 'grep -q "/stack/history/compact" /app/dashboard/index.html' && echo "[OK] dashboard ligado em /stack/history/compact"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase15.sh

echo
echo "[OK] fase 16 validada"
