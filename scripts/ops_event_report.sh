#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

LEDGER_FILE="logs/ops/ops_event_ledger.jsonl"

if [ ! -f "${LEDGER_FILE}" ]; then
  echo "[ERRO] ledger inexistente"
  exit 1
fi

echo "===== OPS EVENT LEDGER REPORT ====="
echo "FILE=${LEDGER_FILE}"
echo

TMP_JSON="/tmp/ops_event_report_$$.json"
jq -s '
{
  total: length,
  by_type: (group_by(.event_type) | map({key: .[0].event_type, value: length}) | from_entries),
  by_status: (map(select(.final_status != "")) | group_by(.final_status) | map({key: .[0].final_status, value: length}) | from_entries),
  last_events: (reverse | .[:10])
}
' "${LEDGER_FILE}" > "${TMP_JSON}"

echo "===== SUMMARY ====="
cat "${TMP_JSON}" | jq '.total, .by_type, .by_status'

echo
echo "===== LAST EVENTS ====="
cat "${TMP_JSON}" | jq -r '.last_events[] | (.created_at + " | " + .event_type + " | " + .actor + " | " + (.final_status // ""))'

rm -f "${TMP_JSON}"

echo
echo "[OK] relatorio do ledger emitido"
