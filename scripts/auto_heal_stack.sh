#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -f .env ]; then
  export $(grep -E '^(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID|INTERNAL_API_KEY)=' .env | xargs)
fi

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
NOW_EPOCH=$(date +%s)

STATE_DIR="logs/state"
LOG_DIR="logs/autoheal"
OUT_FILE="${LOG_DIR}/auto_heal_$(date +%Y%m%d-%H%M%S).log"
META_FILE="${STATE_DIR}/auto_heal_state.json"

COOLDOWN_SECONDS=300
WINDOW_SECONDS=1800
MAX_ATTEMPTS=3

mkdir -p "${STATE_DIR}" "${LOG_DIR}"

if [ ! -f "${META_FILE}" ]; then
  cat > "${META_FILE}" <<EOF
{
  "last_attempt_epoch": 0,
  "attempt_count_window": 0,
  "window_start_epoch": 0,
  "last_action": "",
  "last_result": ""
}
EOF
fi

STACK_OK="$(curl -s http://127.0.0.1:3000/stack/health | jq -r '.ok // false' 2>/dev/null || echo false)"

if [ "${STACK_OK}" = "true" ]; then
  echo "[OK] stack saudavel, auto-heal nao necessario" | tee -a "${OUT_FILE}"
  exit 0
fi

LAST_ATTEMPT=$(jq -r '.last_attempt_epoch // 0' "${META_FILE}")
WINDOW_START=$(jq -r '.window_start_epoch // 0' "${META_FILE}")
ATTEMPTS=$(jq -r '.attempt_count_window // 0' "${META_FILE}")

if [ $((NOW_EPOCH - WINDOW_START)) -gt ${WINDOW_SECONDS} ]; then
  WINDOW_START=${NOW_EPOCH}
  ATTEMPTS=0
fi

if [ $((NOW_EPOCH - LAST_ATTEMPT)) -lt ${COOLDOWN_SECONDS} ]; then
  MSG="[AUTOHEAL][JARVIS] cooldown ativo em ${STAMP}. Nenhuma acao executada."
  echo "${MSG}" | tee -a "${OUT_FILE}"
  exit 0
fi

if [ "${ATTEMPTS}" -ge "${MAX_ATTEMPTS}" ]; then
  MSG="[AUTOHEAL][JARVIS] limite de tentativas atingido em ${STAMP}. Janela de ${WINDOW_SECONDS}s."
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
  exit 1
fi

ATTEMPTS=$((ATTEMPTS + 1))

jq \
  --argjson now "${NOW_EPOCH}" \
  --argjson attempts "${ATTEMPTS}" \
  --argjson window_start "${WINDOW_START}" \
  '.last_attempt_epoch = $now
   | .attempt_count_window = $attempts
   | .window_start_epoch = $window_start
   | .last_action = "docker compose up -d --build"
   | .last_result = "running"' \
  "${META_FILE}" > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "${META_FILE}"

MSG="[AUTOHEAL][JARVIS] tentativa ${ATTEMPTS}/${MAX_ATTEMPTS} iniciada em ${STAMP}"
echo "${MSG}" | tee -a "${OUT_FILE}"
./scripts/send_telegram_alert.sh "${MSG}" || true

{
  echo "===== AUTO HEAL ====="
  date
  docker compose up -d --build
  sleep 20
  echo
  echo "===== VALIDACAO ====="
  ./scripts/validate_fase6.sh
} | tee -a "${OUT_FILE}"

STACK_OK_AFTER="$(curl -s http://127.0.0.1:3000/stack/health | jq -r '.ok // false' 2>/dev/null || echo false)"

if [ "${STACK_OK_AFTER}" = "true" ]; then
  MSG="[AUTOHEAL][JARVIS] stack recuperada com sucesso em ${STAMP}"
  jq --arg result "success" '.last_result = $result' "${META_FILE}" > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "${META_FILE}"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
  exit 0
fi

MSG="[AUTOHEAL][JARVIS] tentativa falhou em ${STAMP}"
jq --arg result "failed" '.last_result = $result' "${META_FILE}" > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "${META_FILE}"
echo "${MSG}" | tee -a "${OUT_FILE}"
./scripts/send_telegram_alert.sh "${MSG}" || true
exit 1
