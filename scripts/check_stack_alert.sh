#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -f .env ]; then
  export $(grep -E '^(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=' .env | xargs)
fi

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
EPOCH_NOW=$(date +%s)

OUT_DIR="logs/alerts"
STATE_DIR="logs/state"
OUT_FILE="${OUT_DIR}/stack_alert_$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="${STATE_DIR}/stack_status.state"
METRICS_FILE="${STATE_DIR}/stack_metrics.json"

mkdir -p "${OUT_DIR}" "${STATE_DIR}"

if [ ! -f "${STATE_FILE}" ]; then
  echo "unknown" > "${STATE_FILE}"
fi

if [ ! -f "${METRICS_FILE}" ]; then
  cat > "${METRICS_FILE}" <<EOF
{
  "date": "$(date +%F)",
  "down_count": 0,
  "last_down_at": "",
  "last_recovered_at": "",
  "last_downtime_seconds": 0,
  "total_downtime_seconds": 0,
  "current_down_since": ""
}
EOF
fi

TODAY="$(date +%F)"
METRICS_DATE=$(jq -r '.date // ""' "${METRICS_FILE}")

if [ "${METRICS_DATE}" != "${TODAY}" ]; then
  cat > "${METRICS_FILE}" <<EOF
{
  "date": "${TODAY}",
  "down_count": 0,
  "last_down_at": "",
  "last_recovered_at": "",
  "last_downtime_seconds": 0,
  "total_downtime_seconds": 0,
  "current_down_since": ""
}
EOF
fi

LAST_STATE=$(cat "${STATE_FILE}" 2>/dev/null || echo "unknown")
CURRENT_STATE="up"
DETAIL=""

RESP=$(curl -s http://127.0.0.1:3000/stack/health || true)

if [ -z "${RESP}" ]; then
  CURRENT_STATE="down"
  DETAIL="stack/health sem resposta"
else
  OK=$(printf "%s" "${RESP}" | jq -r '.ok // false')
  if [ "${OK}" != "true" ]; then
    CURRENT_STATE="down"
    DETAIL="${RESP}"
  fi
fi

if [ "${CURRENT_STATE}" = "down" ] && [ "${LAST_STATE}" != "down" ]; then
  jq \
    --arg stamp "${STAMP}" \
    '.down_count += 1
     | .last_down_at = $stamp
     | .current_down_since = $stamp' \
    "${METRICS_FILE}" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "${METRICS_FILE}"

  MSG="[ALERTA][JARVIS] stack caiu em ${STAMP}"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  echo "${DETAIL}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}"$'\n'"${DETAIL}" || true
  ./scripts/auto_heal_stack.sh || true
fi

if [ "${CURRENT_STATE}" = "up" ] && [ "${LAST_STATE}" = "down" ]; then
  DOWN_AT=$(jq -r '.current_down_since // ""' "${METRICS_FILE}")

  if [ -n "${DOWN_AT}" ] && [ "${DOWN_AT}" != "null" ]; then
    DOWN_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DOWN_AT}" "+%s" 2>/dev/null || echo "${EPOCH_NOW}")
  else
    DOWN_EPOCH="${EPOCH_NOW}"
  fi

  DOWNTIME=$((EPOCH_NOW - DOWN_EPOCH))
  [ "${DOWNTIME}" -lt 0 ] && DOWNTIME=0

  jq \
    --arg stamp "${STAMP}" \
    --argjson downtime "${DOWNTIME}" \
    '.last_recovered_at = $stamp
     | .last_downtime_seconds = $downtime
     | .total_downtime_seconds += $downtime
     | .current_down_since = ""' \
    "${METRICS_FILE}" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "${METRICS_FILE}"

  MSG="[RECUPERADO][JARVIS] stack normalizada em ${STAMP} | indisponibilidade: ${DOWNTIME}s"
  echo "${MSG}" | tee -a "${OUT_FILE}"
  ./scripts/send_telegram_alert.sh "${MSG}" || true
fi

echo "${CURRENT_STATE}" > "${STATE_FILE}"

if [ "${CURRENT_STATE}" = "up" ]; then
  echo "[OK] stack saudavel"
  exit 0
fi

echo "[ALERTA] stack com falha"
exit 1
