#!/usr/bin/env bash
set -e

MSG="${1:-}"
if [ -z "${MSG}" ]; then
  echo "[ERRO] mensagem vazia"
  exit 1
fi

MUTE_FILE="${TELEGRAM_MUTE_FILE:-runtime/TELEGRAM_MUTE}"
STATE_DIR="${TELEGRAM_STATE_DIR:-runtime/telegram}"
SUPPRESSED_LOG="${TELEGRAM_SUPPRESSED_LOG:-logs/telegram/telegram_suppressed.log}"
COOLDOWN_SEC="${TELEGRAM_COOLDOWN_SEC:-1800}"   # 30 min
mkdir -p "${STATE_DIR}" "$(dirname "${SUPPRESSED_LOG}")"

if [ "${TELEGRAM_ALERTS_ENABLED:-1}" = "0" ] || [ -f "${MUTE_FILE}" ]; then
  echo "[MUTED] Telegram bloqueado por chave operacional"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | MUTED | ${MSG}" >> "${SUPPRESSED_LOG}"
  exit 0
fi

if [ -f .env ]; then
  export $(grep -E '^(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=' .env | xargs)
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "[ERRO] TELEGRAM_BOT_TOKEN ou TELEGRAM_CHAT_ID nao definidos"
  exit 1
fi


PATTERN_LOG="${TELEGRAM_PATTERN_LOG:-logs/telegram/vision_flap_internal.log}"
mkdir -p "$(dirname "${PATTERN_LOG}")"

if printf '%s' "${MSG}" | grep -qi 'V.I.S.I.O.N. Offline ou instavel\|V.I.S.I.O.N. Offline ou instável'; then
  FLAP_COUNT_FILE="${STATE_DIR}/vision_flap.count"
  FLAP_COUNT=0
  if [ -f "${FLAP_COUNT_FILE}" ]; then
    FLAP_COUNT="$(cat "${FLAP_COUNT_FILE}" 2>/dev/null || echo 0)"
  fi
  FLAP_COUNT=$((FLAP_COUNT + 1))
  echo "${FLAP_COUNT}" > "${FLAP_COUNT_FILE}"

  if [ "${FLAP_COUNT}" -lt 5 ]; then
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | INTERNAL_ONLY | flap_count=${FLAP_COUNT} | ${MSG}" >> "${PATTERN_LOG}"
    echo "[SUPPRESSED] oscilacao pequena enviada apenas para log interno"
    exit 0
  fi
fi

HASH="$(printf '%s' "${MSG}" | shasum -a 256 | awk '{print $1}')"
STATE_FILE="${STATE_DIR}/${HASH}.state"
NOW="$(date +%s)"

LAST_SENT=0
if [ -f "${STATE_FILE}" ]; then
  LAST_SENT="$(cat "${STATE_FILE}" 2>/dev/null || echo 0)"
fi

ELAPSED=$((NOW - LAST_SENT))

if [ "${ELAPSED}" -lt "${COOLDOWN_SEC}" ]; then
  echo "[SUPPRESSED] cooldown ativo para mensagem repetida"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | SUPPRESSED | cooldown=${COOLDOWN_SEC}s | ${MSG}" >> "${SUPPRESSED_LOG}"
  exit 0
fi

curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  > /dev/null

echo "${NOW}" > "${STATE_FILE}"
echo "[OK] alerta enviado ao Telegram"
