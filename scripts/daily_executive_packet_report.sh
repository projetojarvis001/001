#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um packet valido"
  exit 1
fi

echo "===== DAILY EXECUTIVE PACKET REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"REFERENCE_DAY=" + (.reference_day // ""),
"",
"===== EXECUTIVE SNAPSHOT =====",
(.executive_snapshot | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== OPERATIONAL DISCIPLINE =====",
(.operational_discipline | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DAILY CHANGES =====",
(.daily_changes | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== LATEST RELEASE =====",
(.latest_release | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SOURCES =====",
(.sources | to_entries[] | (.key + "=" + .value))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do packet emitido"
