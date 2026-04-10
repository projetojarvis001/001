#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um promotion log valido"
  exit 1
fi

echo "===== PROMOTION REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"ACTOR=" + (.actor // ""),
"REASON=" + (.reason // ""),
"",
"===== INPUTS =====",
(.inputs | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SOURCES =====",
(.sources | to_entries[] | (.key + "=" + .value)),
"",
"===== READINESS =====",
(.readiness | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RISK =====",
(.risk | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== CHANGE WINDOW =====",
(.change_window | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RESULT =====",
(.result | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de promotion emitido"
