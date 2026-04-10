#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 58 ====="

echo
echo "===== BUILD COMPARE ====="
./scripts/daily_executive_compare.sh

LATEST="$(ls -1t logs/executive/daily_executive_compare_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem compare"
  exit 1
fi

echo "COMPARE_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.today.operational_score >= 0 and .today.operational_score <= 100' "${LATEST}" >/dev/null
jq -e '.previous_day.operational_score >= 0' "${LATEST}" >/dev/null
jq -e '.delta.operational_score != null' "${LATEST}" >/dev/null
jq -e '.delta.executive_signal_changed != null' "${LATEST}" >/dev/null
jq -e '.decision.status == "SEM_BASE" or .decision.status == "MELHORA" or .decision.status == "PIORA" or .decision.status == "ESTAVEL"' "${LATEST}" >/dev/null
echo "[OK] comparativo consistente"

echo
echo "===== REPORT ====="
./scripts/daily_executive_compare_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/daily_executive_compare.sh
bash -n scripts/daily_executive_compare_report.sh
bash -n scripts/validate_fase58.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 58 validada"
