#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/daily_executive_compare_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

TODAY_PACKET="${1:-}"
if [ -z "${TODAY_PACKET}" ]; then
  TODAY_PACKET="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
fi

HISTORY_FILE="logs/executive/operational_score_history.json"

if [ -z "${TODAY_PACKET}" ] || [ ! -f "${TODAY_PACKET}" ]; then
  echo "[ERRO] informe um daily_executive_packet valido"
  exit 1
fi

if [ ! -f "${HISTORY_FILE}" ]; then
  echo "[ERRO] historico de score nao encontrado"
  exit 1
fi

TODAY_REF="$(jq -r '.reference_day // ""' "${TODAY_PACKET}")"
TODAY_SCORE="$(jq -r '.operational_discipline.score // 0' "${TODAY_PACKET}")"
TODAY_SIGNAL="$(jq -r '.decision.executive_signal // "UNKNOWN"' "${TODAY_PACKET}")"
TODAY_RISK_RELEASES="$(jq -r '.daily_changes.risk_releases // 0' "${TODAY_PACKET}")"
TODAY_BLOCKED_RELEASES="$(jq -r '.daily_changes.blocked_releases // 0' "${TODAY_PACKET}")"
TODAY_ROLLBACK_RELEASES="$(jq -r '.daily_changes.rollback_releases // 0' "${TODAY_PACKET}")"
TODAY_RELIABILITY="$(jq -r '.latest_release.reliability_score // 0' "${TODAY_PACKET}")"
TODAY_GO_LIVE="$(jq -r '.executive_snapshot.go_live_status // "UNKNOWN"' "${TODAY_PACKET}")"

PREV_DAY="$(jq -r --arg d "${TODAY_REF}" '[.[] | select(.reference_day < $d)] | sort_by(.reference_day) | last | .reference_day // ""' "${HISTORY_FILE}")"

if [ -z "${PREV_DAY}" ]; then
  PREV_SCORE=0
  PREV_SIGNAL="N/A"
  PREV_RISK_RELEASES=0
  PREV_BLOCKED_RELEASES=0
  PREV_ROLLBACK_RELEASES=0
  PREV_RELIABILITY=0
  PREV_GO_LIVE="N/A"
else
  PREV_PACKET="$(find logs/executive -maxdepth 1 -type f -name 'daily_executive_packet_*.json' | sort | while read -r f; do
    ref="$(jq -r '.reference_day // ""' "$f" 2>/dev/null || true)"
    if [ "$ref" = "${PREV_DAY}" ]; then
      echo "$f"
    fi
  done | tail -n 1)"

  if [ -n "${PREV_PACKET}" ] && [ -f "${PREV_PACKET}" ]; then
    PREV_SCORE="$(jq -r '.operational_discipline.score // 0' "${PREV_PACKET}")"
    PREV_SIGNAL="$(jq -r '.decision.executive_signal // "UNKNOWN"' "${PREV_PACKET}")"
    PREV_RISK_RELEASES="$(jq -r '.daily_changes.risk_releases // 0' "${PREV_PACKET}")"
    PREV_BLOCKED_RELEASES="$(jq -r '.daily_changes.blocked_releases // 0' "${PREV_PACKET}")"
    PREV_ROLLBACK_RELEASES="$(jq -r '.daily_changes.rollback_releases // 0' "${PREV_PACKET}")"
    PREV_RELIABILITY="$(jq -r '.latest_release.reliability_score // 0' "${PREV_PACKET}")"
    PREV_GO_LIVE="$(jq -r '.executive_snapshot.go_live_status // "UNKNOWN"' "${PREV_PACKET}")"
  else
    PREV_SCORE="$(jq -r --arg d "${PREV_DAY}" '.[] | select(.reference_day == $d) | .final_score' "${HISTORY_FILE}" | tail -n 1)"
    PREV_SIGNAL="N/A"
    PREV_RISK_RELEASES=0
    PREV_BLOCKED_RELEASES=0
    PREV_ROLLBACK_RELEASES=0
    PREV_RELIABILITY=0
    PREV_GO_LIVE="N/A"
  fi
fi

DELTA_SCORE=$((TODAY_SCORE - PREV_SCORE))
DELTA_RISK=$((TODAY_RISK_RELEASES - PREV_RISK_RELEASES))
DELTA_BLOCKED=$((TODAY_BLOCKED_RELEASES - PREV_BLOCKED_RELEASES))
DELTA_ROLLBACK=$((TODAY_ROLLBACK_RELEASES - PREV_ROLLBACK_RELEASES))
DELTA_RELIABILITY=$((TODAY_RELIABILITY - PREV_RELIABILITY))

SIGNAL_CHANGED=false
if [ "${TODAY_SIGNAL}" != "${PREV_SIGNAL}" ]; then
  SIGNAL_CHANGED=true
fi

STATUS="ESTAVEL"
NOTE="Sem variacao material relevante frente ao dia anterior."

if [ "${PREV_DAY}" = "" ]; then
  STATUS="SEM_BASE"
  NOTE="Sem base historica anterior para comparacao."
elif [ "${DELTA_SCORE}" -ge 5 ] && [ "${DELTA_BLOCKED}" -le 0 ] && [ "${DELTA_ROLLBACK}" -le 0 ]; then
  STATUS="MELHORA"
  NOTE="Melhora operacional frente ao dia anterior."
elif [ "${DELTA_SCORE}" -le -5 ] || [ "${DELTA_BLOCKED}" -gt 0 ] || [ "${DELTA_ROLLBACK}" -gt 0 ]; then
  STATUS="PIORA"
  NOTE="Piora operacional frente ao dia anterior. Revisar mudancas e governanca."
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg today_ref "${TODAY_REF}" \
  --arg prev_ref "${PREV_DAY}" \
  --arg today_signal "${TODAY_SIGNAL}" \
  --arg prev_signal "${PREV_SIGNAL}" \
  --arg today_go_live "${TODAY_GO_LIVE}" \
  --arg prev_go_live "${PREV_GO_LIVE}" \
  --argjson today_score "${TODAY_SCORE}" \
  --argjson prev_score "${PREV_SCORE}" \
  --argjson today_risk "${TODAY_RISK_RELEASES}" \
  --argjson prev_risk "${PREV_RISK_RELEASES}" \
  --argjson today_blocked "${TODAY_BLOCKED_RELEASES}" \
  --argjson prev_blocked "${PREV_BLOCKED_RELEASES}" \
  --argjson today_rollback "${TODAY_ROLLBACK_RELEASES}" \
  --argjson prev_rollback "${PREV_ROLLBACK_RELEASES}" \
  --argjson today_reliability "${TODAY_RELIABILITY}" \
  --argjson prev_reliability "${PREV_RELIABILITY}" \
  --argjson delta_score "${DELTA_SCORE}" \
  --argjson delta_risk "${DELTA_RISK}" \
  --argjson delta_blocked "${DELTA_BLOCKED}" \
  --argjson delta_rollback "${DELTA_ROLLBACK}" \
  --argjson delta_reliability "${DELTA_RELIABILITY}" \
  --argjson signal_changed "${SIGNAL_CHANGED}" \
  --arg status "${STATUS}" \
  --arg note "${NOTE}" \
  '{
    created_at: $created_at,
    today: {
      reference_day: $today_ref,
      executive_signal: $today_signal,
      go_live_status: $today_go_live,
      operational_score: $today_score,
      risk_releases: $today_risk,
      blocked_releases: $today_blocked,
      rollback_releases: $today_rollback,
      release_reliability_score: $today_reliability
    },
    previous_day: {
      reference_day: $prev_ref,
      executive_signal: $prev_signal,
      go_live_status: $prev_go_live,
      operational_score: $prev_score,
      risk_releases: $prev_risk,
      blocked_releases: $prev_blocked,
      rollback_releases: $prev_rollback,
      release_reliability_score: $prev_reliability
    },
    delta: {
      operational_score: $delta_score,
      risk_releases: $delta_risk,
      blocked_releases: $delta_blocked,
      rollback_releases: $delta_rollback,
      release_reliability_score: $delta_reliability,
      executive_signal_changed: $signal_changed
    },
    decision: {
      status: $status,
      operator_note: $note
    }
  }' > "${OUT_FILE}"

echo "[OK] comparativo executivo gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
