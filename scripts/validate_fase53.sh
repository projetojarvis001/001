#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 53 ====="

echo
echo "===== CENARIO A: PROMOCAO SAUDAVEL ====="
./scripts/executive_semaphore.sh
LATEST="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"

jq -e '.inputs.post_deploy_status == "PASS"' "${LATEST}" >/dev/null
jq -e '.inputs.auto_rollback_status == "NOT_RUN"' "${LATEST}" >/dev/null
echo "[OK] semaphore nao herdou rollback antigo"

echo
echo "===== CHECK JSON ====="
jq -e '.semaphore.color == "GREEN" or .semaphore.color == "YELLOW" or .semaphore.color == "RED" or .semaphore.color == "BLACK"' "${LATEST}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST}" >/dev/null
echo "[OK] semaphore consistente"

echo
echo "===== VIEW ====="
cat "${LATEST}" | jq '.semaphore, .inputs, .decision'

echo
echo "===== SANIDADE ====="
bash -n scripts/executive_semaphore.sh
bash -n scripts/validate_fase53.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 53 validada"
