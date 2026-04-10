#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== DIAGNOSTICO ====="
./scripts/diagnose_stack.sh | tee /tmp/diag_fase12.json

KIND=$(jq -r '.kind' /tmp/diag_fase12.json)
OK=$(jq -r '.ok' /tmp/diag_fase12.json)

if [ "${OK}" != "true" ] && [ -z "${KIND}" ]; then
  echo "[ERRO] diagnostico sem classificacao"
  exit 1
fi

echo
echo "===== STACK HEALTH ====="
curl -fsS http://127.0.0.1:3000/stack/health | jq .

echo
echo "===== AUTO HEAL STATUS ====="
./scripts/show_auto_heal_status.sh

echo
echo "===== TESTE AUTOHEAL EM STACK SAUDAVEL ====="
./scripts/auto_heal_stack.sh

echo
echo "[OK] fase 12 validada"
