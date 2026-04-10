#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um semaphore valido"
  exit 1
fi

echo "===== EXECUTIVE SEMAPHORE REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== SEMAPHORE =====",
(.semaphore | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== INPUTS =====",
(.inputs | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do semaforo emitido"
