#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 29 ====="

echo
echo "===== CHAOS SUITE ====="
./scripts/run_chaos_suite.sh

LATEST=$(ls -1t logs/chaos_suite/chaos_suite_*.json | head -n 1)
test -f "${LATEST}"
echo "[OK] suite selecionada: ${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.status != null' "${LATEST}" >/dev/null
jq -e '.total != null' "${LATEST}" >/dev/null
jq -e '.pass != null' "${LATEST}" >/dev/null
jq -e '.fail != null' "${LATEST}" >/dev/null
jq -e '.cases != null' "${LATEST}" >/dev/null
echo "[OK] json consolidado consistente"

echo
echo "===== REPORT ====="
./scripts/chaos_suite_report.sh "${LATEST}"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase28.sh

echo
echo "[OK] fase 29 validada"
