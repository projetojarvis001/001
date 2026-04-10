#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/daily_change_summary_$(date +%Y%m%d-%H%M%S).json"

LEDGER_FILE="logs/ops/ops_event_ledger.jsonl"
FREEZE_FILE="logs/state/change_freeze.active"

mkdir -p "${OUT_DIR}" logs/ops logs/state

TODAY_UTC="$(date -u +"%Y-%m-%d")"

if [ ! -f "${LEDGER_FILE}" ]; then
  echo "[ERRO] ledger operacional inexistente"
  exit 1
fi

TMP_DAY="/tmp/daily_change_summary_${RANDOM}.json"

jq -s --arg day "${TODAY_UTC}" '
  map(select((.created_at // "") | startswith($day)))
' "${LEDGER_FILE}" > "${TMP_DAY}"

TOTAL_EVENTS="$(jq 'length' "${TMP_DAY}")"
PROMOTION_COUNT="$(jq '[.[] | select(.event_type == "promotion")] | length' "${TMP_DAY}")"
MANIFEST_COUNT="$(jq '[.[] | select(.event_type == "manifest")] | length' "${TMP_DAY}")"
FREEZE_COUNT="$(jq '[.[] | select(.event_type == "freeze")] | length' "${TMP_DAY}")"

RISK_RELEASES="$(jq '[.[] | select(.event_type == "promotion" and .final_status == "LIBERAR_COM_RISCO")] | length' "${TMP_DAY}")"
FULL_RELEASES="$(jq '[.[] | select(.event_type == "promotion" and .final_status == "LIBERAR")] | length' "${TMP_DAY}")"
BLOCKED_RELEASES="$(jq '[.[] | select(.event_type == "promotion" and .final_status == "BLOQUEAR")] | length' "${TMP_DAY}")"
ROLLBACK_RELEASES="$(jq '[.[] | select(.event_type == "promotion" and (.final_status == "ROLLBACK_EXECUTADO" or .final_status == "ROLLBACK_FALHOU"))] | length' "${TMP_DAY}")"

LAST_PROMOTION_STATUS="$(jq -r '
  [.[] | select(.event_type == "promotion")] | last | .final_status // ""
' "${TMP_DAY}")"

LAST_PROMOTION_AT="$(jq -r '
  [.[] | select(.event_type == "promotion")] | last | .created_at // ""
' "${TMP_DAY}")"

LAST_FREEZE_AT="$(jq -r '
  [.[] | select(.event_type == "freeze")] | last | .created_at // ""
' "${TMP_DAY}")"

FREEZE_ACTIVE=false
if [ -f "${FREEZE_FILE}" ]; then
  FREEZE_ACTIVE=true
fi

EXECUTIVE_SIGNAL="SEM_EVENTOS"
if [ "${BLOCKED_RELEASES}" -gt 0 ] || [ "${ROLLBACK_RELEASES}" -gt 0 ]; then
  EXECUTIVE_SIGNAL="ATENCAO"
fi

if [ "${RISK_RELEASES}" -gt 0 ]; then
  EXECUTIVE_SIGNAL="OPERACAO_CONTROLADA"
fi

if [ "${FULL_RELEASES}" -gt 0 ] && [ "${RISK_RELEASES}" -eq 0 ] && [ "${BLOCKED_RELEASES}" -eq 0 ] && [ "${ROLLBACK_RELEASES}" -eq 0 ]; then
  EXECUTIVE_SIGNAL="FLUXO_NORMAL"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg reference_day "${TODAY_UTC}" \
  --arg last_promotion_status "${LAST_PROMOTION_STATUS}" \
  --arg last_promotion_at "${LAST_PROMOTION_AT}" \
  --arg last_freeze_at "${LAST_FREEZE_AT}" \
  --arg executive_signal "${EXECUTIVE_SIGNAL}" \
  --argjson total_events "${TOTAL_EVENTS}" \
  --argjson promotion_count "${PROMOTION_COUNT}" \
  --argjson manifest_count "${MANIFEST_COUNT}" \
  --argjson freeze_count "${FREEZE_COUNT}" \
  --argjson full_releases "${FULL_RELEASES}" \
  --argjson risk_releases "${RISK_RELEASES}" \
  --argjson blocked_releases "${BLOCKED_RELEASES}" \
  --argjson rollback_releases "${ROLLBACK_RELEASES}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  --slurpfile day "${TMP_DAY}" '
  {
    created_at: $created_at,
    reference_day: $reference_day,
    summary: {
      total_events: $total_events,
      promotion_count: $promotion_count,
      manifest_count: $manifest_count,
      freeze_count: $freeze_count
    },
    releases: {
      full_releases: $full_releases,
      risk_releases: $risk_releases,
      blocked_releases: $blocked_releases,
      rollback_releases: $rollback_releases,
      last_promotion_status: $last_promotion_status,
      last_promotion_at: $last_promotion_at
    },
    freeze: {
      active: $freeze_active,
      last_freeze_at: $last_freeze_at
    },
    decision: {
      executive_signal: $executive_signal,
      operator_note:
        (if $executive_signal == "FLUXO_NORMAL" then
          "Dia operacional normal, sem desvios relevantes."
         elif $executive_signal == "OPERACAO_CONTROLADA" then
          "Houve liberacoes com risco controlado. Manter observacao."
         elif $executive_signal == "ATENCAO" then
          "Ocorreram bloqueios ou rollback. Revisar governanca operacional."
         else
          "Sem eventos relevantes no ledger do dia."
         end)
    },
    events: ($day[0] // [])
  }' > "${OUT_FILE}"

rm -f "${TMP_DAY}"

echo "[OK] resumo diario gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
