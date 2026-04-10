#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 52 ====="

echo
echo "===== BUILD SEMAPHORE ====="
./scripts/executive_semaphore.sh

LATEST="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem semaphore"
  exit 1
fi

echo "SEMAPHORE_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.semaphore.color == "GREEN" or .semaphore.color == "YELLOW" or .semaphore.color == "RED" or .semaphore.color == "BLACK"' "${LATEST}" >/dev/null
jq -e '.semaphore.severity != null' "${LATEST}" >/dev/null
jq -e '.inputs.score >= 0 and .inputs.score <= 100' "${LATEST}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST}" >/dev/null
echo "[OK] semaphore consistente"

echo
echo "===== REPORT ====="
./scripts/executive_semaphore_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/executive_semaphore.sh
bash -n scripts/executive_semaphore_report.sh
bash -n scripts/validate_fase52.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 52 validada"
