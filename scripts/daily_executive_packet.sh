#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/daily_executive_packet_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" logs/executive logs/release logs/readiness

DASH_FILE="$(ls -1t logs/executive/executive_ops_dashboard.json 2>/dev/null | head -n 1 || true)"
SUMMARY_FILE="$(ls -1t logs/executive/daily_change_summary_*.json 2>/dev/null | head -n 1 || true)"
SCORE_FILE="$(ls -1t logs/executive/operational_score_[0-9]*.json 2>/dev/null | head -n 1 || true)"
TREND_FILE="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"
SEMAPHORE_FILE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"
RELIABILITY_FILE="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
TIMELINE_FILE="$(ls -1t logs/release/release_timeline_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"

for f in "${DASH_FILE}" "${SUMMARY_FILE}" "${SCORE_FILE}" "${TREND_FILE}" "${SEMAPHORE_FILE}" "${RELIABILITY_FILE}" "${TIMELINE_FILE}" "${MANIFEST_FILE}"; do
  if [ -z "${f}" ] || [ ! -f "${f}" ]; then
    echo "[ERRO] artefato obrigatorio ausente: ${f}"
    exit 1
  fi
done

REF_DAY="$(jq -r '.reference_day // ""' "${SUMMARY_FILE}")"
if [ -z "${REF_DAY}" ]; then
  REF_DAY="$(date +%Y-%m-%d)"
fi

READINESS="$(jq -r '.executive.readiness // "UNKNOWN"' "${DASH_FILE}")"
GO_LIVE="$(jq -r '.decision.go_live_status // "UNKNOWN"' "${DASH_FILE}")"
RISK_LEVEL="$(jq -r '.governance.risk_level // "UNKNOWN"' "${DASH_FILE}")"
DAY_SCORE="$(jq -r '.scoring.final_score // 0' "${SCORE_FILE}")"
DAY_GRADE="$(jq -r '.scoring.grade // "N/A"' "${SCORE_FILE}")"
DAY_STATUS="$(jq -r '.scoring.status // "N/A"' "${SCORE_FILE}")"
TREND="$(jq -r '.summary.trend // "UNKNOWN"' "${TREND_FILE}")"
EXEC_BAND="$(jq -r '.summary.executive_band // "INDEFINIDA"' "${TREND_FILE}")"
SEMAPHORE_COLOR="$(jq -r '.semaphore.color // "UNKNOWN"' "${SEMAPHORE_FILE}")"
SEMAPHORE_SEVERITY="$(jq -r '.semaphore.severity // "UNKNOWN"' "${SEMAPHORE_FILE}")"

TOTAL_EVENTS="$(jq -r '.summary.total_events // 0' "${SUMMARY_FILE}")"
PROMOTION_COUNT="$(jq -r '.summary.promotion_count // 0' "${SUMMARY_FILE}")"
FREEZE_COUNT="$(jq -r '.summary.freeze_count // 0' "${SUMMARY_FILE}")"
RISK_RELEASES="$(jq -r '.releases.risk_releases // 0' "${SUMMARY_FILE}")"
BLOCKED_RELEASES="$(jq -r '.releases.blocked_releases // 0' "${SUMMARY_FILE}")"
ROLLBACK_RELEASES="$(jq -r '.releases.rollback_releases // 0' "${SUMMARY_FILE}")"

REL_SCORE="$(jq -r '.scoring.final_score // 0' "${RELIABILITY_FILE}")"
REL_GRADE="$(jq -r '.scoring.grade // "N/A"' "${RELIABILITY_FILE}")"
REL_STATUS="$(jq -r '.scoring.status // "N/A"' "${RELIABILITY_FILE}")"

REL_FINAL_STATUS="$(jq -r '.context.final_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_POST_STATUS="$(jq -r '.context.post_status // "UNKNOWN"' "${RELIABILITY_FILE}")"
REL_ROLLBACK_STATUS="$(jq -r '.context.rollback_status // "UNKNOWN"' "${RELIABILITY_FILE}")"

TIMELINE_FINAL_STATUS="$(jq -r '.decision.final_status // "UNKNOWN"' "${TIMELINE_FILE}")"
MANIFEST_FINAL_STATUS="$(jq -r '.execution.final_status // "UNKNOWN"' "${MANIFEST_FILE}")"

EXEC_SIGNAL="NORMAL"
EXEC_NOTE="Dia operacional normal."

if [ "${SEMAPHORE_COLOR}" = "BLACK" ] || [ "${REL_ROLLBACK_STATUS}" = "ROLLBACK_FALHOU" ]; then
  EXEC_SIGNAL="CRITICO"
  EXEC_NOTE="Operacao em estado critico. Freeze, rollback ou falha grave exigem revisao imediata."
elif [ "${SEMAPHORE_COLOR}" = "RED" ] || [ "${BLOCKED_RELEASES}" -gt 0 ] || [ "${ROLLBACK_RELEASES}" -gt 0 ]; then
  EXEC_SIGNAL="ATENCAO"
  EXEC_NOTE="Dia com bloqueios ou rollback. Revisar governanca operacional."
elif [ "${SEMAPHORE_COLOR}" = "YELLOW" ] || [ "${RISK_RELEASES}" -gt 0 ] || [ "${GO_LIVE}" = "LIBERAR_COM_RISCO" ]; then
  EXEC_SIGNAL="CONTROLADO"
  EXEC_NOTE="Dia com liberacoes controladas e concessoes gerenciais."
else
  EXEC_SIGNAL="NORMAL"
  EXEC_NOTE="Operacao sob controle, sem desvios relevantes."
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg reference_day "${REF_DAY}" \
  --arg dash_file "${DASH_FILE}" \
  --arg summary_file "${SUMMARY_FILE}" \
  --arg score_file "${SCORE_FILE}" \
  --arg trend_file "${TREND_FILE}" \
  --arg semaphore_file "${SEMAPHORE_FILE}" \
  --arg reliability_file "${RELIABILITY_FILE}" \
  --arg timeline_file "${TIMELINE_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg readiness "${READINESS}" \
  --arg go_live "${GO_LIVE}" \
  --arg risk_level "${RISK_LEVEL}" \
  --argjson day_score "${DAY_SCORE}" \
  --arg day_grade "${DAY_GRADE}" \
  --arg day_status "${DAY_STATUS}" \
  --arg trend "${TREND}" \
  --arg executive_band "${EXEC_BAND}" \
  --arg semaphore_color "${SEMAPHORE_COLOR}" \
  --arg semaphore_severity "${SEMAPHORE_SEVERITY}" \
  --argjson total_events "${TOTAL_EVENTS}" \
  --argjson promotion_count "${PROMOTION_COUNT}" \
  --argjson freeze_count "${FREEZE_COUNT}" \
  --argjson risk_releases "${RISK_RELEASES}" \
  --argjson blocked_releases "${BLOCKED_RELEASES}" \
  --argjson rollback_releases "${ROLLBACK_RELEASES}" \
  --argjson rel_score "${REL_SCORE}" \
  --arg rel_grade "${REL_GRADE}" \
  --arg rel_status "${REL_STATUS}" \
  --arg rel_final_status "${REL_FINAL_STATUS}" \
  --arg rel_post_status "${REL_POST_STATUS}" \
  --arg rel_rollback_status "${REL_ROLLBACK_STATUS}" \
  --arg timeline_final_status "${TIMELINE_FINAL_STATUS}" \
  --arg manifest_final_status "${MANIFEST_FINAL_STATUS}" \
  --arg executive_signal "${EXEC_SIGNAL}" \
  --arg operator_note "${EXEC_NOTE}" \
  '{
    created_at: $created_at,
    reference_day: $reference_day,
    sources: {
      dashboard_file: $dash_file,
      summary_file: $summary_file,
      score_file: $score_file,
      trend_file: $trend_file,
      semaphore_file: $semaphore_file,
      reliability_file: $reliability_file,
      timeline_file: $timeline_file,
      manifest_file: $manifest_file
    },
    executive_snapshot: {
      readiness: $readiness,
      go_live_status: $go_live,
      risk_level: $risk_level,
      semaphore_color: $semaphore_color,
      semaphore_severity: $semaphore_severity
    },
    operational_discipline: {
      score: $day_score,
      grade: $day_grade,
      status: $day_status,
      trend: $trend,
      executive_band: $executive_band
    },
    daily_changes: {
      total_events: $total_events,
      promotion_count: $promotion_count,
      freeze_count: $freeze_count,
      risk_releases: $risk_releases,
      blocked_releases: $blocked_releases,
      rollback_releases: $rollback_releases
    },
    latest_release: {
      reliability_score: $rel_score,
      reliability_grade: $rel_grade,
      reliability_status: $rel_status,
      final_status: $rel_final_status,
      timeline_final_status: $timeline_final_status,
      manifest_final_status: $manifest_final_status,
      post_deploy_status: $rel_post_status,
      rollback_status: $rel_rollback_status
    },
    decision: {
      executive_signal: $executive_signal,
      operator_note: $operator_note
    }
  }' > "${OUT_FILE}"

echo "[OK] daily executive packet gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
