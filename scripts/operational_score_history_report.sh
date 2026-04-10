#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-logs/executive/operational_score_history.json}"

if [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] historico nao encontrado"
  exit 1
fi

echo "===== OPERATIONAL SCORE HISTORY REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"TOTAL_DIAS=" + (length|tostring),
"",
"===== ULTIMOS REGISTROS =====",
(if length == 0
 then "nenhum_registro"
 else .[-10:][] | (
   .reference_day + " | score=" + (.final_score|tostring) +
   " | grade=" + (.grade // "") +
   " | status=" + (.status // "") +
   " | go_live=" + (.go_live_status // "")
 )
 end)
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do historico emitido"
