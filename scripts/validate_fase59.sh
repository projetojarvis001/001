#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 59 ====="

echo
echo "===== BUILD CAUSES ====="
./scripts/operational_degradation_causes.sh

LATEST="$(ls -1t logs/executive/operational_degradation_causes_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem arquivo de causas"
  exit 1
fi

echo "CAUSES_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.top_causes | type == "array"' "${LATEST}" >/dev/null
jq -e '.top_causes | length >= 1' "${LATEST}" >/dev/null
jq -e '.decision.main_driver != null' "${LATEST}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST}" >/dev/null
echo "[OK] causas consistentes"

echo
echo "===== CHECK ORDER ====="
jq -e '
  ([.top_causes[].weight] == ([.top_causes[].weight] | sort | reverse))
  or (.top_causes | length == 1)
' "${LATEST}" >/dev/null
echo "[OK] ranking ordenado por peso"

echo
echo "===== CHECK EXPECTED DRIVERS ====="
jq -e '.top_causes[] | select(.cause == "risk_release" or .cause == "release_with_risk")' "${LATEST}" >/dev/null
echo "[OK] degradadores esperados presentes"

echo
echo "===== REPORT ====="
./scripts/operational_degradation_causes_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/operational_degradation_causes.sh
bash -n scripts/operational_degradation_causes_report.sh
bash -n scripts/validate_fase59.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 59 validada"
