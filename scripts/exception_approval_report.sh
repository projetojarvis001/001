#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/readiness/exception_check_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um exception_check valido"
  exit 1
fi

echo "===== EXCEPTION APPROVAL REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== SOURCE =====",
(.source | to_entries[] | (.key + "=" + .value)),
"",
"===== APPROVAL =====",
(.approval | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RESULT =====",
(.result | to_entries[] | (.key + "=" + .value))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de aprovacao emitido"
