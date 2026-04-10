#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/change_window_$(date +%Y%m%d-%H%M%S).json"
FREEZE_FILE="logs/readiness/change_freeze.flag"

mkdir -p "${OUT_DIR}"

WINDOW_START="${WINDOW_START:-09:00}"
WINDOW_END="${WINDOW_END:-18:00}"
ALLOW_OUTSIDE_WINDOW="${ALLOW_OUTSIDE_WINDOW:-0}"
NOW_HM="$(date +%H:%M)"

to_minutes() {
  local hh mm
  hh="$(printf "%s" "$1" | cut -d: -f1)"
  mm="$(printf "%s" "$1" | cut -d: -f2)"
  echo $((10#${hh} * 60 + 10#${mm}))
}

NOW_MIN="$(to_minutes "${NOW_HM}")"
START_MIN="$(to_minutes "${WINDOW_START}")"
END_MIN="$(to_minutes "${WINDOW_END}")"

FREEZE_ACTIVE=false
if [ -f "${FREEZE_FILE}" ]; then
  FREEZE_ACTIVE=true
fi

WITHIN_WINDOW=false
if [ "${NOW_MIN}" -ge "${START_MIN}" ] && [ "${NOW_MIN}" -le "${END_MIN}" ]; then
  WITHIN_WINDOW=true
fi

STATUS="OPEN"
NOTE="Janela operacional aberta."
AUTHORIZED=true
MODE="NORMAL"

if [ "${FREEZE_ACTIVE}" = "true" ]; then
  STATUS="BLOCKED_FREEZE"
  NOTE="Mudancas bloqueadas por freeze operacional."
  AUTHORIZED=false
fi

if [ "${FREEZE_ACTIVE}" != "true" ] && [ "${WITHIN_WINDOW}" != "true" ]; then
  STATUS="BLOCKED_WINDOW"
  NOTE="Fora da janela operacional permitida."
  AUTHORIZED=false
fi

if [ "${AUTHORIZED}" != "true" ] && [ "${ALLOW_OUTSIDE_WINDOW}" = "1" ]; then
  STATUS="OVERRIDE"
  NOTE="Liberado por override explicito fora da politica padrao."
  AUTHORIZED=true
  MODE="OVERRIDE_EXPLICITO"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg now_hm "${NOW_HM}" \
  --arg window_start "${WINDOW_START}" \
  --arg window_end "${WINDOW_END}" \
  --arg status "${STATUS}" \
  --arg note "${NOTE}" \
  --arg mode "${MODE}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  --argjson within_window "${WITHIN_WINDOW}" \
  --argjson authorized "${AUTHORIZED}" \
  --arg allow_outside_window "${ALLOW_OUTSIDE_WINDOW}" \
  '{
    created_at: $created_at,
    policy: {
      window_start: $window_start,
      window_end: $window_end,
      allow_outside_window: ($allow_outside_window == "1")
    },
    runtime: {
      now_hm: $now_hm,
      freeze_active: $freeze_active,
      within_window: $within_window
    },
    decision: {
      status: $status,
      authorized: $authorized,
      mode: $mode,
      operator_note: $note
    }
  }' > "${OUT_FILE}"

echo "[OK] change window gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
