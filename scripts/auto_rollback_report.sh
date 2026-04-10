#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/release/auto_rollback_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um auto rollback log valido"
  exit 1
fi

echo "===== AUTO ROLLBACK REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"ACTOR=" + (.actor // ""),
"REASON=" + (.reason // ""),
"",
"===== SOURCE =====",
(.source | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RESULT =====",
(.result | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de auto rollback emitido"
