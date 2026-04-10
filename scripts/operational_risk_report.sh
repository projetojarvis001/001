#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um operational_risk valido"
  exit 1
fi

echo "===== OPERATIONAL RISK REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"RISK_LEVEL=" + (.decision.risk_level // ""),
"GO_LIVE_STATUS=" + (.decision.go_live_status // ""),
"CHANGE_POLICY=" + (.decision.change_policy // ""),
"NOTE=" + (.decision.operator_note // ""),
"",
"===== HEALTH =====",
(.health | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== OBSERVABILITY =====",
(.observability | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== OPERATIONS =====",
(.operations | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de risco emitido"
