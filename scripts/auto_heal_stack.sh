#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP="$(date '+%Y-%m-%d %H:%M:%S')"
EPOCH_NOW="$(date +%s)"

STATE_DIR="logs/state"
LOG_DIR="logs/autoheal"
STATE_FILE="${STATE_DIR}/auto_heal_state.json"
OUT_FILE="${LOG_DIR}/auto_heal_$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${STATE_DIR}" "${LOG_DIR}"

if [ ! -f "${STATE_FILE}" ]; then
  cat > "${STATE_FILE}" <<'JSON'
{
  "last_attempt_epoch": 0,
  "attempt_count_window": 0,
  "window_start_epoch": 0,
  "last_action": "",
  "last_result": "",
  "last_kind": ""
}
JSON
fi

LAST_ATTEMPT="$(jq -r '.last_attempt_epoch // 0' "${STATE_FILE}")"
ATTEMPT_COUNT="$(jq -r '.attempt_count_window // 0' "${STATE_FILE}")"
WINDOW_START="$(jq -r '.window_start_epoch // 0' "${STATE_FILE}")"

COOLDOWN_SECONDS=300
WINDOW_SECONDS=1800
MAX_ATTEMPTS=3

if [ $((EPOCH_NOW - LAST_ATTEMPT)) -lt "${COOLDOWN_SECONDS}" ]; then
  echo "[SKIP] cooldown ativo" | tee -a "${OUT_FILE}"
  exit 0
fi

if [ "${WINDOW_START}" -eq 0 ] || [ $((EPOCH_NOW - WINDOW_START)) -gt "${WINDOW_SECONDS}" ]; then
  WINDOW_START="${EPOCH_NOW}"
  ATTEMPT_COUNT=0
fi

if [ "${ATTEMPT_COUNT}" -ge "${MAX_ATTEMPTS}" ]; then
  MSG="[AUTOHEAL][JARVIS] limite de tentativas atingido na janela"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
  exit 1
fi

DIAG_JSON="$(./scripts/diagnose_stack.sh)"
KIND="$(printf "%s" "${DIAG_JSON}" | jq -r '.kind')"
DETAIL="$(printf "%s" "${DIAG_JSON}" | jq -r '.detail')"
OK="$(printf "%s" "${DIAG_JSON}" | jq -r '.ok')"

if [ "${OK}" = "true" ]; then
  echo "[OK] stack saudavel, auto-heal nao necessario" | tee -a "${OUT_FILE}"
  exit 0
fi

ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))

jq \
  --argjson last_attempt_epoch "${EPOCH_NOW}" \
  --argjson attempt_count_window "${ATTEMPT_COUNT}" \
  --argjson window_start_epoch "${WINDOW_START}" \
  --arg last_kind "${KIND}" \
  '.last_attempt_epoch = $last_attempt_epoch
   | .attempt_count_window = $attempt_count_window
   | .window_start_epoch = $window_start_epoch
   | .last_kind = $last_kind' \
  "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"

ACTION=""
NOTIFY_ONLY="false"

case "${KIND}" in
  core_local)
    ACTION="docker compose restart jarvis-core"
    ;;
  redis_local)
    ACTION="docker compose restart redis"
    ;;
  postgres_local)
    ACTION="docker compose restart postgres"
    ;;
  vision_remote_bridge)
    ACTION="alert_only_bridge"
    NOTIFY_ONLY="true"
    ;;
  vision_remote_semantic)
    ACTION="alert_only_semantic"
    NOTIFY_ONLY="true"
    ;;
  vision_remote_whisper)
    ACTION="alert_only_whisper"
    NOTIFY_ONLY="true"
    ;;
  unknown)
    ACTION="docker compose up -d --build"
    ;;
  *)
    ACTION="docker compose up -d --build"
    ;;
esac

{
  echo "===== AUTO HEAL ====="
  date
  echo "KIND=${KIND}"
  echo "DETAIL=${DETAIL}"
  echo "ACTION=${ACTION}"
  echo
} | tee -a "${OUT_FILE}"

if [ "${NOTIFY_ONLY}" = "true" ]; then
  MSG="[AUTOHEAL][JARVIS] dependência externa com falha: ${KIND} | ${DETAIL}"
  jq --arg action "${ACTION}" --arg result "notify_only" \
    '.last_action = $action | .last_result = $result' \
    "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
  exit 1
fi

{
  echo "===== EXEC ====="
  eval "${ACTION}"
  echo
  echo "===== AGUARDANDO ====="
  sleep 20
  echo
  echo "===== VALIDACAO ====="
  ./scripts/validate_fase6.sh
} | tee -a "${OUT_FILE}"

STACK_OK_AFTER="$(curl -s http://127.0.0.1:3000/stack/health | jq -r '.ok // false' 2>/dev/null || echo false)"

if [ "${STACK_OK_AFTER}" = "true" ]; then
  MSG="[AUTOHEAL][JARVIS] stack recuperada com sucesso em ${STAMP} | causa: ${KIND} | acao: ${ACTION}"
  jq --arg action "${ACTION}" --arg result "success" \
    '.last_action = $action | .last_result = $result' \
    "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
  exit 0
fi

MSG="[AUTOHEAL][JARVIS] tentativa falhou em ${STAMP} | causa: ${KIND} | acao: ${ACTION}"
jq --arg action "${ACTION}" --arg result "failed" \
  '.last_action = $action | .last_result = $result' \
  "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
echo "${MSG}" | tee -a "${OUT_FILE}"
./scripts/send_telegram_alert.sh "${MSG}" || true
exit 1
