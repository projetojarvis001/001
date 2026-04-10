#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/history"
OUT_FILE="${OUT_DIR}/stack_daily_history.json"

mkdir -p "${OUT_DIR}"

SLO_JSON=$(curl -fsS http://127.0.0.1:3000/stack/slo)
METRICS_JSON=$(curl -fsS http://127.0.0.1:3000/stack/metrics)

DATE_REF=$(printf "%s" "${SLO_JSON}" | jq -r '.date // empty')
[ -z "${DATE_REF}" ] && DATE_REF=$(date +%F)

AVAIL=$(printf "%s" "${SLO_JSON}" | jq -r '.availability_percent // 0')
DOWNTIME=$(printf "%s" "${SLO_JSON}" | jq -r '.downtime_seconds // 0')
STATUS=$(printf "%s" "${SLO_JSON}" | jq -r '.status // "unknown"')
TARGET=$(printf "%s" "${SLO_JSON}" | jq -r '.target_percent // 99.9')
COLLECTED=$(printf "%s" "${SLO_JSON}" | jq -r '.timestamp // empty')

INCIDENTS=$(printf "%s" "${METRICS_JSON}" | jq -r '.metrics.down_count // 0')
LAST_DOWNTIME=$(printf "%s" "${METRICS_JSON}" | jq -r '.metrics.last_downtime_seconds // 0')

NEW_ROW=$(jq -n \
  --arg date "${DATE_REF}" \
  --argjson availability "${AVAIL}" \
  --argjson downtime "${DOWNTIME}" \
  --argjson incidents "${INCIDENTS}" \
  --argjson last_downtime "${LAST_DOWNTIME}" \
  --arg status "${STATUS}" \
  --argjson target "${TARGET}" \
  --arg collected_at "${COLLECTED}" \
  '{
    date: $date,
    availability_percent: $availability,
    downtime_seconds: $downtime,
    incident_count: $incidents,
    last_downtime_seconds: $last_downtime,
    status: $status,
    target_percent: $target,
    collected_at: $collected_at
  }')

if [ ! -f "${OUT_FILE}" ]; then
  echo '[]' > "${OUT_FILE}"
fi

TMP=$(mktemp)

jq \
  --argjson newRow "${NEW_ROW}" \
  '
  map(select(.date != $newRow.date))
  + [$newRow]
  | sort_by(.date)
  | if length > 90 then .[-90:] else . end
  ' "${OUT_FILE}" > "${TMP}"

mv "${TMP}" "${OUT_FILE}"

echo "[OK] historico atualizado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
