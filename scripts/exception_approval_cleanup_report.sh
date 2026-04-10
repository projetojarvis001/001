#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/readiness/exception_cleanup_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um cleanup valido"
  exit 1
fi

echo "===== EXCEPTION CLEANUP REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== SUMMARY =====",
(.summary | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== ITEMS =====",
(if (.items|length) == 0
 then "nenhum_item"
 else (.items[] | (.file + " | " + .status + " | expires_at=" + (.expires_at // "") + " | actor=" + (.actor // "")))
 end)
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de cleanup emitido"
