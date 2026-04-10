#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
EPOCH_NOW=$(date +%s)

OUT_DIR="logs/alerts"
OUT_FILE="${OUT_DIR}/stack_alert_$(date +%Y%m%d-%H%M%S).log"

STATE_DIR="logs/state"
STATE_FILE="${STATE_DIR}/stack_status.state"
METRICS_FILE="${STATE_DIR}/stack_metrics.json"
ALERT_STATE_FILE="${STATE_DIR}/alert_state.json"

mkdir -p "${OUT_DIR}" "${STATE_DIR}"

TODAY=$(date '+%Y-%m-%d')

if [ ! -f "${METRICS_FILE}" ]; then
  cat > "${METRICS_FILE}" <<JSON
{
  "date": "${TODAY}",
  "down_count": 0,
  "last_down_at": "",
  "last_recovered_at": "",
  "last_downtime_seconds": 0,
  "total_downtime_seconds": 0,
  "current_down_since": ""
}
JSON
fi

DATE_REF=$(jq -r '.date // ""' "${METRICS_FILE}")
if [ "${DATE_REF}" != "${TODAY}" ]; then
  cat > "${METRICS_FILE}" <<JSON
{
  "date": "${TODAY}",
  "down_count": 0,
  "last_down_at": "",
  "last_recovered_at": "",
  "last_downtime_seconds": 0,
  "total_downtime_seconds": 0,
  "current_down_since": ""
}
JSON
fi

if [ ! -f "${ALERT_STATE_FILE}" ]; then
  cat > "${ALERT_STATE_FILE}" <<'JSON'
{
  "last_alert_key": "",
  "last_alert_at": 0,
  "last_severity": "",
  "repeat_count": 0,
  "last_recovery_at": 0
}
JSON
fi

LAST_STATE="unknown"
if [ -f "${STATE_FILE}" ]; then
  LAST_STATE=$(cat "${STATE_FILE}" 2>/dev/null || echo unknown)
fi

CLASS_JSON="$(./scripts/classify_stack_alert.sh)"
SEVERITY="$(printf "%s" "${CLASS_JSON}" | jq -r '.severity // "WARN"')"
ALERT_KEY="$(printf "%s" "${CLASS_JSON}" | jq -r '.alert_key // "unknown"')"
TITLE="$(printf "%s" "${CLASS_JSON}" | jq -r '.title // "falha não classificada"')"
DETAIL="$(printf "%s" "${CLASS_JSON}" | jq -r '.detail // "sem detalhe"')"

CURRENT_STATE="up"
if [ "${ALERT_KEY}" != "healthy" ]; then
  CURRENT_STATE="down"
fi

case "${SEVERITY}" in
  CRITICAL) SILENCE_WINDOW=300 ;;
  HIGH) SILENCE_WINDOW=900 ;;
  WARN) SILENCE_WINDOW=1800 ;;
  INFO) SILENCE_WINDOW=3600 ;;
  *) SILENCE_WINDOW=3600 ;;
esac

LAST_ALERT_KEY=$(jq -r '.last_alert_key // ""' "${ALERT_STATE_FILE}")
LAST_ALERT_AT=$(jq -r '.last_alert_at // 0' "${ALERT_STATE_FILE}")
LAST_SEVERITY=$(jq -r '.last_severity // ""' "${ALERT_STATE_FILE}")

SECONDS_SINCE_LAST=$((EPOCH_NOW - LAST_ALERT_AT))
[ "${SECONDS_SINCE_LAST}" -lt 0 ] && SECONDS_SINCE_LAST=999999

should_send_alert="false"

if [ "${CURRENT_STATE}" = "down" ]; then
  if [ "${ALERT_KEY}" != "${LAST_ALERT_KEY}" ] || [ "${SEVERITY}" != "${LAST_SEVERITY}" ]; then
    should_send_alert="true"
  elif [ "${SECONDS_SINCE_LAST}" -ge "${SILENCE_WINDOW}" ]; then
    should_send_alert="true"
  fi
fi

if [ "${CURRENT_STATE}" = "down" ] && [ "${LAST_STATE}" != "down" ]; then
  jq \
    --arg stamp "${STAMP}" \
    '.down_count += 1
     | .last_down_at = $stamp
     | .current_down_since = $stamp' \
    "${METRICS_FILE}" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "${METRICS_FILE}"
fi

if [ "${CURRENT_STATE}" = "up" ] && [ "${LAST_STATE}" = "down" ]; then
  DOWN_SINCE=$(jq -r '.current_down_since // ""' "${METRICS_FILE}")
  DOWNTIME=0

  if [ -n "${DOWN_SINCE}" ] && [ "${DOWN_SINCE}" != "null" ]; then
    DOWN_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DOWN_SINCE}" "+%s" 2>/dev/null || echo 0)
    if [ "${DOWN_EPOCH}" -gt 0 ]; then
      DOWNTIME=$((EPOCH_NOW - DOWN_EPOCH))
      [ "${DOWNTIME}" -lt 0 ] && DOWNTIME=0
    fi
  fi

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

  jq \
    --argjson ts "${EPOCH_NOW}" \
    '.last_recovery_at = $ts
     | .repeat_count = 0' \
    "${ALERT_STATE_FILE}" > "${ALERT_STATE_FILE}.tmp" && mv "${ALERT_STATE_FILE}.tmp" "${ALERT_STATE_FILE}"
fi

if [ "${CURRENT_STATE}" = "down" ]; then
  MSG="[${SEVERITY}][JARVIS] ${TITLE} em ${STAMP}"
  FULL_MSG="${MSG}"$'\n'"${DETAIL}"

  echo "${MSG}" | tee -a "${OUT_FILE}"
  echo "${DETAIL}" | tee -a "${OUT_FILE}"

  if [ "${should_send_alert}" = "true" ]; then
    ./scripts/send_telegram_alert.sh "${FULL_MSG}" || true

    jq \
      --arg key "${ALERT_KEY}" \
      --arg sev "${SEVERITY}" \
      --argjson ts "${EPOCH_NOW}" \
      '.last_alert_key = $key
       | .last_alert_at = $ts
       | .last_severity = $sev
       | .repeat_count += 1' \
      "${ALERT_STATE_FILE}" > "${ALERT_STATE_FILE}.tmp" && mv "${ALERT_STATE_FILE}.tmp" "${ALERT_STATE_FILE}"
  else
    echo "[INFO] alerta deduplicado por janela de silencio" | tee -a "${OUT_FILE}"
  fi

  ./scripts/auto_heal_stack.sh || true
fi

echo "${CURRENT_STATE}" > "${STATE_FILE}"

if [ "${CURRENT_STATE}" = "up" ]; then
  echo "[OK] stack saudavel"
  exit 0
fi

echo "[ALERTA] stack com falha"
exit 1
