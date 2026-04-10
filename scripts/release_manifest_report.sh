#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um release manifest valido"
  exit 1
fi

echo "===== RELEASE MANIFEST REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== RELEASE IDENTITY =====",
(.release_identity | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== GOVERNANCE =====",
(.governance | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== EXECUTION =====",
(.execution | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== OBSERVABILITY =====",
(.observability | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== GIT =====",
(.git | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== SOURCES =====",
(.sources | to_entries[] | (.key + "=" + .value))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio de manifest emitido"
