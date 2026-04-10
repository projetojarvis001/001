#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/post_deploy_verify_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3}"

STACK_OK=false
CORE_OK=false
SEMANTIC_OK=false
WHISPER_OK=false
BRIDGE_OK=false
HTTP_STATUS=0
ATTEMPTS=0
LAST_STACK='{}'

echo "===== POST DEPLOY VERIFY ====="
echo "MAX_WAIT_SECONDS=${MAX_WAIT_SECONDS}"
echo "SLEEP_SECONDS=${SLEEP_SECONDS}"

START_EPOCH=$(date +%s)
DEADLINE=$((START_EPOCH + MAX_WAIT_SECONDS))

while true; do
  ATTEMPTS=$((ATTEMPTS + 1))

  HTTP_STATUS=$(curl -s -o /tmp/post_deploy_health.json -w "%{http_code}" http://127.0.0.1:3000/stack/health || echo 000)

  if [ "${HTTP_STATUS}" = "200" ] && jq empty /tmp/post_deploy_health.json >/dev/null 2>&1; then
    LAST_STACK="$(cat /tmp/post_deploy_health.json)"
    STACK_OK="$(printf "%s" "${LAST_STACK}" | jq -r '.ok // false')"
    CORE_OK="$(printf "%s" "${LAST_STACK}" | jq -r '.checks.core.ok // false')"
    SEMANTIC_OK="$(printf "%s" "${LAST_STACK}" | jq -r '.checks.semantic.ok // false')"
    WHISPER_OK="$(printf "%s" "${LAST_STACK}" | jq -r '.checks.whisper.ok // false')"
    BRIDGE_OK="$(printf "%s" "${LAST_STACK}" | jq -r '.checks.bridge.ok // false')"

    echo "ATTEMPT=${ATTEMPTS} HTTP=${HTTP_STATUS} STACK_OK=${STACK_OK} CORE=${CORE_OK} SEMANTIC=${SEMANTIC_OK} WHISPER=${WHISPER_OK} BRIDGE=${BRIDGE_OK}"

    if [ "${STACK_OK}" = "true" ] && \
       [ "${CORE_OK}" = "true" ] && \
       [ "${SEMANTIC_OK}" = "true" ] && \
       [ "${WHISPER_OK}" = "true" ] && \
       [ "${BRIDGE_OK}" = "true" ]; then
      break
    fi
  else
    echo "ATTEMPT=${ATTEMPTS} HTTP=${HTTP_STATUS} STACK_JSON_INVALID"
  fi

  NOW_EPOCH=$(date +%s)
  if [ "${NOW_EPOCH}" -ge "${DEADLINE}" ]; then
    break
  fi

  sleep "${SLEEP_SECONDS}"
done

FINAL_STATUS="PASS"
FINAL_NOTE="Post-deploy confirmado com stack saudavel."

if [ "${STACK_OK}" != "true" ] || \
   [ "${CORE_OK}" != "true" ] || \
   [ "${SEMANTIC_OK}" != "true" ] || \
   [ "${WHISPER_OK}" != "true" ] || \
   [ "${BRIDGE_OK}" != "true" ]; then
  FINAL_STATUS="FAIL"
  FINAL_NOTE="Post-deploy falhou. Stack nao estabilizou dentro da janela."
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson attempts "${ATTEMPTS}" \
  --argjson max_wait_seconds "${MAX_WAIT_SECONDS}" \
  --argjson sleep_seconds "${SLEEP_SECONDS}" \
  --argjson http_status "${HTTP_STATUS}" \
  --arg status "${FINAL_STATUS}" \
  --arg note "${FINAL_NOTE}" \
  --argjson stack "$(printf "%s" "${LAST_STACK}")" \
  '{
    created_at: $created_at,
    policy: {
      max_wait_seconds: $max_wait_seconds,
      sleep_seconds: $sleep_seconds
    },
    execution: {
      attempts: $attempts,
      last_http_status: $http_status
    },
    result: {
      status: $status,
      note: $note
    },
    stack_health: $stack
  }' > "${OUT_FILE}"

echo
echo "[OK] post deploy verify gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

if [ "${FINAL_STATUS}" = "PASS" ]; then
  exit 0
fi

exit 1
