#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/daily_executive_compare_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um compare valido"
  exit 1
fi

echo "===== DAILY EXECUTIVE COMPARE REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== TODAY =====",
(.today | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== PREVIOUS DAY =====",
(.previous_day | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DELTA =====",
(.delta | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do comparativo emitido"
