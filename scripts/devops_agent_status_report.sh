#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"
if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE="$(ls -1t logs/executive/devops_agent_status_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um status valido"
  exit 1
fi

echo "===== DEVOPS AGENT STATUS REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== GIT =====",
(.git | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RUNTIME =====",
(.runtime | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== CONTAINERS =====",
(.containers | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== GOVERNANCE =====",
(.governance | to_entries[] | (.key + "=" + (.value|tostring)))
' "${INPUT_FILE}"

echo
echo "[OK] relatorio do status emitido"
