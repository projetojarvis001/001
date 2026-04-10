#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

JSON_FILE="logs/history/stack_daily_history.json"
CSV_FILE="logs/history/stack_daily_history.csv"

mkdir -p logs/history

if [ ! -f "${JSON_FILE}" ]; then
  echo '[]' > "${JSON_FILE}"
fi

jq -r '
  (["date","availability_percent","downtime_seconds","incident_count","last_downtime_seconds","status","target_percent","collected_at"]),
  (.[] | [
    (.date // ""),
    (.availability_percent // 0),
    (.downtime_seconds // 0),
    (.incident_count // 0),
    (.last_downtime_seconds // 0),
    (.status // ""),
    (.target_percent // 0),
    (.collected_at // "")
  ])
  | @csv
' "${JSON_FILE}" > "${CSV_FILE}"

COUNT=$(jq 'length' "${JSON_FILE}")
echo "[OK] CSV exportado em ${CSV_FILE} com ${COUNT} registros"
head -n 5 "${CSV_FILE}" || true
