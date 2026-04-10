#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/daily_change_summary_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um daily_change_summary valido"
  exit 1
fi

echo "===== DAILY CHANGE SUMMARY REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"REFERENCE_DAY=" + (.reference_day // ""),
"",
"===== SUMMARY =====",
(.summary | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RELEASES =====",
(.releases | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== FREEZE =====",
(.freeze | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== LAST EVENTS =====",
(if (.events | length) == 0
 then "nenhum_evento"
 else (.events[-5:][] | (.created_at + " | " + .event_type + " | " + .actor + " | " + (.final_status // "")))
 end)
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do resumo diario emitido"
