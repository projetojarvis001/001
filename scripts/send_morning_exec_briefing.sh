#!/usr/bin/env bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -f .env ]; then
  export $(grep -E '^(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=' .env | xargs)
fi

HEALTH=$(curl -fsS http://127.0.0.1:3000/stack/health)
SLO=$(curl -fsS http://127.0.0.1:3000/stack/slo)
HIST=$(curl -fsS http://127.0.0.1:3000/stack/history/compact)

AUTO_FILE="logs/state/auto_heal_state.json"
if [ -f "${AUTO_FILE}" ]; then
  AUTO=$(cat "${AUTO_FILE}")
else
  AUTO='{"last_action":"","last_result":""}'
fi

STACK_OK=$(printf "%s" "${HEALTH}" | jq -r '.ok // false')
CURRENT_STATUS="degradado"
[ "${STACK_OK}" = "true" ] && CURRENT_STATUS="saudável"

SLO_DAY=$(printf "%s" "${SLO}" | jq -r '.availability_percent // 0')
AVG7=$(printf "%s" "${HIST}" | jq -r '.summary.average_availability_percent_7d // 0')
DOWN7=$(printf "%s" "${HIST}" | jq -r '.summary.total_downtime_seconds_7d // 0')
INC7=$(printf "%s" "${HIST}" | jq -r '.summary.total_incidents_7d // 0')
TREND=$(printf "%s" "${HIST}" | jq -r '.summary.trend_7d // "STABLE"')
EXEC=$(printf "%s" "${HIST}" | jq -r '.summary.executive_status // "ESTAVEL"')

LAST_ACTION=$(printf "%s" "${AUTO}" | jq -r '.last_action // ""')
LAST_RESULT=$(printf "%s" "${AUTO}" | jq -r '.last_result // ""')

[ -z "${LAST_ACTION}" ] && LAST_ACTION="nenhuma"
[ -z "${LAST_RESULT}" ] && LAST_RESULT="n/a"

MSG="[JARVIS][BRIEFING STACK VISION]
Status atual: ${CURRENT_STATUS}
SLO do dia: ${SLO_DAY}%
Disponibilidade média 7d: ${AVG7}%
Downtime 7d: ${DOWN7}s
Incidentes 7d: ${INC7}
Tendência: ${TREND}
Status executivo: ${EXEC}
Última ação de auto-heal: ${LAST_ACTION}
Resultado do auto-heal: ${LAST_RESULT}"

echo "${MSG}"

./scripts/send_telegram_alert.sh "${MSG}"
