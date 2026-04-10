#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 13 ====="

echo
echo "===== STACK METRICS ====="
curl -fsS http://127.0.0.1:3000/stack/metrics | jq .

echo
echo "===== CHECK CAMPOS ====="
curl -fsS http://127.0.0.1:3000/stack/metrics > /tmp/stack_metrics_f13.json
jq -e '.ok == true' /tmp/stack_metrics_f13.json >/dev/null
jq -e '.metrics != null' /tmp/stack_metrics_f13.json >/dev/null
jq -e '.autoHeal != null' /tmp/stack_metrics_f13.json >/dev/null
echo "[OK] endpoint /stack/metrics consistente"

echo
echo "===== DASHBOARD ====="
docker exec jarvis-jarvis-core-1 sh -lc 'grep -q "/stack/metrics" /app/dashboard/index.html' && echo "[OK] dashboard ligado em /stack/metrics"

echo
echo "===== HEALTH GERAL ====="
./scripts/validate_fase6.sh

echo
echo "[OK] fase 13 validada"
