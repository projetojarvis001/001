#!/usr/bin/env bash
set -e

echo "===== REGRESSAO ====="
./scripts/check_vision_regression.sh

echo
echo "===== HEALTH CORE ====="
curl -fsS http://127.0.0.1:3000/health >/dev/null && echo "[OK] core"

echo
echo "===== STACK HEALTH ====="
curl -fsS http://127.0.0.1:3000/stack/health >/tmp/stack_health.json
cat /tmp/stack_health.json

echo
echo "===== SEM HEADER ====="
CODE_NO=$(curl -s -o /tmp/nohdr.out -w "%{http_code}" \
  -X POST http://127.0.0.1:3000/semantic-proxy/cmd \
  -H "Content-Type: application/json" \
  -d '{"prompt":"teste","model":"qwen2.5:7b"}')
echo "HTTP=$CODE_NO"
cat /tmp/nohdr.out
echo
[ "$CODE_NO" = "401" ] && echo "[OK] bloqueado sem header"

echo
echo "===== COM HEADER ====="
CODE_YES=$(curl -s -o /tmp/yeshdr.out -w "%{http_code}" \
  -X POST http://127.0.0.1:3000/semantic-proxy/cmd \
  -H "Content-Type: application/json" \
  -H "x-internal-key: jarvis-internal-2026-fase6" \
  -d '{"prompt":"teste","model":"qwen2.5:7b"}')
echo "HTTP=$CODE_YES"
cat /tmp/yeshdr.out
echo
if [ "$CODE_YES" = "200" ] || [ "$CODE_YES" = "400" ] || [ "$CODE_YES" = "502" ]; then
  echo "[OK] rota autenticada respondeu"
else
  echo "[ERRO] resposta inesperada com header"
  exit 1
fi

echo
echo "===== STATUS CONTAINER ====="
docker ps --format 'table {{.Names}}\t{{.Status}}'

echo
echo "[OK] fase 6 validada"
