#!/usr/bin/env bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATE_FILE="logs/state/stack_metrics.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "[ERRO] metrics file nao encontrado: ${STATE_FILE}"
  exit 1
fi

DATE_REF=$(jq -r '.date // ""' "${STATE_FILE}")
DOWN_COUNT=$(jq -r '.down_count // 0' "${STATE_FILE}")
LAST_DOWN=$(jq -r '.last_down_at // ""' "${STATE_FILE}")
LAST_RECOVERED=$(jq -r '.last_recovered_at // ""' "${STATE_FILE}")
LAST_DOWNTIME=$(jq -r '.last_downtime_seconds // 0' "${STATE_FILE}")
TOTAL_DOWNTIME=$(jq -r '.total_downtime_seconds // 0' "${STATE_FILE}")

MSG="[RESUMO DIARIO][JARVIS]
Data: ${DATE_REF}
Quedas no dia: ${DOWN_COUNT}
Ultima queda: ${LAST_DOWN}
Ultima recuperacao: ${LAST_RECOVERED}
Duracao do ultimo incidente: ${LAST_DOWNTIME}s
Downtime acumulado do dia: ${TOTAL_DOWNTIME}s"

echo "${MSG}"
./scripts/send_telegram_alert.sh "${MSG}"
