#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

INPUT_FILE="${1:-}"

if [ -z "${INPUT_FILE}" ]; then
  INPUT_FILE=$(ls -1t logs/release/post_deploy_verify_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${INPUT_FILE}" ] || [ ! -f "${INPUT_FILE}" ]; then
  echo "[ERRO] informe um post_deploy_verify valido"
  exit 1
fi

echo "===== POST DEPLOY REPORT ====="
echo "FILE=${INPUT_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== POLICY =====",
(.policy | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== EXECUTION =====",
(.execution | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== RESULT =====",
(.result | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== STACK HEALTH =====",
"ok=" + (.stack_health.ok|tostring),
"core_ok=" + (.stack_health.checks.core.ok|tostring),
"semantic_ok=" + (.stack_health.checks.semantic.ok|tostring),
"whisper_ok=" + (.stack_health.checks.whisper.ok|tostring),
"bridge_ok=" + (.stack_health.checks.bridge.ok|tostring)
' "${INPUT_FILE}"

echo
echo "[OK] relatorio post deploy emitido"
