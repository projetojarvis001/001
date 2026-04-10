#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um reliability valido"
  exit 1
fi

echo "===== RELEASE RELIABILITY REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== CONTEXT =====",
(.context | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SCORING =====",
(.scoring | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SOURCES =====",
(.sources | to_entries[] | (.key + "=" + .value))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de reliability emitido"
