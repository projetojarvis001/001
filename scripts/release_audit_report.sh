#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um release log valido"
  exit 1
fi

echo "===== RELEASE AUDIT REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"ACTOR=" + (.actor // ""),
"REASON=" + (.reason // ""),
"ALLOW_RISKY_RELEASE=" + (.allow_risky_release|tostring),
"",
"===== INPUTS =====",
(.inputs | to_entries[] | (.key + "=" + .value)),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RESULT =====",
(.result | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] auditoria emitida"
