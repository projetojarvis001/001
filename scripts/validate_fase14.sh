#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 14 ====="

echo
echo "===== STACK SLO ====="
curl -fsS http://127.0.0.1:3000/stack/slo | jq .

echo
echo "===== CHECK SLO ====="
curl -fsS http://127.0.0.1:3000/stack/slo > /tmp/stack_slo_f14.json
jq -e '.ok == true' /tmp/stack_slo_f14.json >/dev/null
jq -e '.availability_percent != null' /tmp/stack_slo_f14.json >/dev/null
jq -e '.target_percent != null' /tmp/stack_slo_f14.json >/dev/null
jq -e '.status != null' /tmp/stack_slo_f14.json >/dev/null
echo "[OK] endpoint /stack/slo consistente"

echo
echo "===== DASHBOARD ====="
docker exec jarvis-jarvis-core-1 sh -lc 'grep -q "/stack/slo" /app/dashboard/index.html' && echo "[OK] dashboard ligado em /stack/slo"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase13.sh

echo
echo "[OK] fase 14 validada"
