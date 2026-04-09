#!/usr/bin/env bash
set -e

echo "===== REGRESSAO ====="
./scripts/check_vision_regression.sh

echo
echo "===== CORE ====="
curl -fsS http://127.0.0.1:3000/health >/dev/null && echo "[OK] core"

echo
echo "===== SEMANTIC PROXY ====="
curl -fsS http://127.0.0.1:3000/semantic-proxy/health >/dev/null && echo "[OK] semantic-proxy"

echo
echo "===== WHISPER PROXY EXISTE ====="
CODE=$(curl -s -o /tmp/whisper.out -w "%{http_code}" -X POST http://127.0.0.1:3000/whisper-proxy/transcribe || true)
if [ "$CODE" = "400" ] || [ "$CODE" = "502" ]; then
  echo "[OK] whisper-proxy respondeu ($CODE)"
else
  echo "[ERRO] whisper-proxy inesperado: $CODE"
  cat /tmp/whisper.out 2>/dev/null || true
  exit 1
fi

echo
echo "===== DASHBOARD ====="
docker exec jarvis-jarvis-core-1 sh -lc 'grep -q "fetch('\''/semantic-proxy/health'\'')" /app/dashboard/index.html' && echo "[OK] dashboard local"

echo
echo "===== SENTINEL ====="
docker logs --tail 120 jarvis-jarvis-core-1 2>&1 | grep -E 'VISION: ONLINE|Sentinel' >/dev/null && echo "[OK] sentinel online"

echo
echo "[OK] fase 5 validada"
