#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/operational_degradation_causes_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um arquivo de causas valido"
  exit 1
fi

echo "===== OPERATIONAL DEGRADATION CAUSES REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"EXECUTIVE_SIGNAL=" + (.executive_signal // ""),
"",
"===== TOP CAUSES =====",
(.top_causes[] | (.cause + " | weight=" + (.weight|tostring) + " | scope=" + .scope + " | source=" + .source + " | note=" + .note)),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de causas emitido"
