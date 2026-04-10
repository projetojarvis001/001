#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um trend valido"
  exit 1
fi

echo "===== OPERATIONAL SCORE TREND REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"SOURCE_FILE=" + (.source_file // ""),
"",
"===== SUMMARY =====",
(.summary | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== HIGHLIGHTS =====",
"best_day=" + ((.highlights.best_day.reference_day // "") + " score=" + ((.highlights.best_day.final_score // 0)|tostring)),
"worst_day=" + ((.highlights.worst_day.reference_day // "") + " score=" + ((.highlights.worst_day.final_score // 0)|tostring)),
"latest_day=" + ((.highlights.latest_day.reference_day // "") + " score=" + ((.highlights.latest_day.final_score // 0)|tostring)),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de tendencia emitido"
