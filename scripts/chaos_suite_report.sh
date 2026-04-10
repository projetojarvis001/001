#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um relatorio chaos_suite valido"
  exit 1
fi

echo "===== CHAOS SUITE REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"STATUS_GERAL=" + .status,
"TOTAL=" + (.total|tostring),
"PASS=" + (.pass|tostring),
"FAIL=" + (.fail|tostring),
"",
"===== CENARIOS =====",
(.cases[] | (.name + " => " + .status + " | " + .started_at + " -> " + .finished_at))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio emitido"
