#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 22 ====="

echo
echo "===== BRIDGE DOWN ====="
./scripts/chaos_test_bridge_down.sh

echo
echo "===== SEMANTIC DOWN ====="
./scripts/chaos_test_semantic_down.sh

echo
echo "===== WHISPER DOWN ====="
./scripts/chaos_test_whisper_down.sh

echo
echo "===== CHECK LOGS ====="
ls -1t logs/chaos | head -n 10

echo
echo "===== AGUARDA ESTABILIZACAO FINAL ====="
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
    echo "[OK] /health no ciclo ${i}"
    break
  fi
  sleep 2
done

for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3000/stack/health >/dev/null 2>&1; then
    echo "[OK] /stack/health no ciclo ${i}"
    break
  fi
  sleep 2
done

for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3000/stack/history/export >/dev/null 2>&1; then
    echo "[OK] /stack/history/export no ciclo ${i}"
    break
  fi
  sleep 2
done

echo
echo "===== HEALTH FINAL ====="
curl -fsS http://127.0.0.1:3000/stack/health | jq .

echo
echo "===== HISTORY EXPORT FINAL ====="
curl -fsS http://127.0.0.1:3000/stack/history/export | jq .

echo
echo "===== BASE ====="
./scripts/validate_fase20.sh

echo
echo "[OK] fase 22 validada"
