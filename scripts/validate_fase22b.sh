#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 22B ====="

echo
echo "===== VALIDATE FASE 22 ====="
./scripts/validate_fase22.sh

echo
echo "===== CHECAGEM BRIDGE CONTIDA ====="
LATEST_BRIDGE=$(ls -1t logs/chaos/chaos_bridge_down_*.log | head -n 1)
grep -q 'ACTION=remote_bridge_only_alert' "${LATEST_BRIDGE}"
grep -q 'dependencia remota indisponivel' "${LATEST_BRIDGE}"
echo "[OK] bridge tratado como dependencia remota"

echo
echo "===== CHECAGEM FINAL ====="
curl -fsS http://127.0.0.1:3000/health | jq .
curl -fsS http://127.0.0.1:3000/stack/health | jq .
curl -fsS http://127.0.0.1:3000/stack/history/export | jq .
echo "[OK] stack estabilizada apos chaos remoto"

echo
echo "[OK] fase 22b validada"
