#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
mkdir -p "${OUT_DIR}" docs/generated logs/ops

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="${OUT_DIR}/phase61_stage_closure_${TS}.json"
OUT_MD="docs/generated/phase61_stage_closure_${TS}.md"

LATEST_PACKET="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
LATEST_SCORE="$(ls -1t logs/executive/operational_score_[0-9]*.json 2>/dev/null | head -n 1 || true)"
LATEST_TREND="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"
LATEST_SEMAPHORE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"
LATEST_RELIABILITY="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
LATEST_TIMELINE="$(ls -1t logs/release/release_timeline_*.json 2>/dev/null | head -n 1 || true)"
LATEST_MANIFEST="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
LATEST_BUNDLE_INDEX="logs/executive/audit_bundle_index.json"
TELEGRAM_MUTE_PRESENT=false
[ -f runtime/TELEGRAM_MUTE ] && TELEGRAM_MUTE_PRESENT=true

PACKET_REF_DAY=""
PACKET_SIGNAL="N/A"
PACKET_GO="N/A"
DAY_SCORE=0
DAY_GRADE="N/A"
DAY_STATUS="N/A"
TREND="UNKNOWN"
TREND_BAND="INDEFINIDA"
REL_SCORE=0
REL_GRADE="N/A"
REL_STATUS="N/A"
REL_FINAL="N/A"
SEM_COLOR="N/A"
SEM_SEVERITY="N/A"
TIMELINE_FINAL="N/A"
MANIFEST_FINAL="N/A"

[ -n "${LATEST_PACKET}" ] && [ -f "${LATEST_PACKET}" ] && PACKET_REF_DAY="$(jq -r '.reference_day // ""' "${LATEST_PACKET}")"
[ -n "${LATEST_PACKET}" ] && [ -f "${LATEST_PACKET}" ] && PACKET_SIGNAL="$(jq -r '.decision.executive_signal // "N/A"' "${LATEST_PACKET}")"
[ -n "${LATEST_PACKET}" ] && [ -f "${LATEST_PACKET}" ] && PACKET_GO="$(jq -r '.executive_snapshot.go_live_status // "N/A"' "${LATEST_PACKET}")"

[ -n "${LATEST_SCORE}" ] && [ -f "${LATEST_SCORE}" ] && DAY_SCORE="$(jq -r '.scoring.final_score // 0' "${LATEST_SCORE}")"
[ -n "${LATEST_SCORE}" ] && [ -f "${LATEST_SCORE}" ] && DAY_GRADE="$(jq -r '.scoring.grade // "N/A"' "${LATEST_SCORE}")"
[ -n "${LATEST_SCORE}" ] && [ -f "${LATEST_SCORE}" ] && DAY_STATUS="$(jq -r '.scoring.status // "N/A"' "${LATEST_SCORE}")"

[ -n "${LATEST_TREND}" ] && [ -f "${LATEST_TREND}" ] && TREND="$(jq -r '.summary.trend // "UNKNOWN"' "${LATEST_TREND}")"
[ -n "${LATEST_TREND}" ] && [ -f "${LATEST_TREND}" ] && TREND_BAND="$(jq -r '.summary.executive_band // "INDEFINIDA"' "${LATEST_TREND}")"

[ -n "${LATEST_RELIABILITY}" ] && [ -f "${LATEST_RELIABILITY}" ] && REL_SCORE="$(jq -r '.scoring.final_score // 0' "${LATEST_RELIABILITY}")"
[ -n "${LATEST_RELIABILITY}" ] && [ -f "${LATEST_RELIABILITY}" ] && REL_GRADE="$(jq -r '.scoring.grade // "N/A"' "${LATEST_RELIABILITY}")"
[ -n "${LATEST_RELIABILITY}" ] && [ -f "${LATEST_RELIABILITY}" ] && REL_STATUS="$(jq -r '.scoring.status // "N/A"' "${LATEST_RELIABILITY}")"
[ -n "${LATEST_RELIABILITY}" ] && [ -f "${LATEST_RELIABILITY}" ] && REL_FINAL="$(jq -r '.context.final_status // "N/A"' "${LATEST_RELIABILITY}")"

[ -n "${LATEST_SEMAPHORE}" ] && [ -f "${LATEST_SEMAPHORE}" ] && SEM_COLOR="$(jq -r '.semaphore.color // "N/A"' "${LATEST_SEMAPHORE}")"
[ -n "${LATEST_SEMAPHORE}" ] && [ -f "${LATEST_SEMAPHORE}" ] && SEM_SEVERITY="$(jq -r '.semaphore.severity // "N/A"' "${LATEST_SEMAPHORE}")"

[ -n "${LATEST_TIMELINE}" ] && [ -f "${LATEST_TIMELINE}" ] && TIMELINE_FINAL="$(jq -r '.decision.final_status // "N/A"' "${LATEST_TIMELINE}")"
[ -n "${LATEST_MANIFEST}" ] && [ -f "${LATEST_MANIFEST}" ] && MANIFEST_FINAL="$(jq -r '.execution.final_status // "N/A"' "${LATEST_MANIFEST}")"

CLOSURE_READY=false
if [ "${REL_SCORE}" -ge 0 ] && [ -n "${LATEST_MANIFEST}" ] && [ -n "${LATEST_TIMELINE}" ] && [ -n "${LATEST_RELIABILITY}" ]; then
  CLOSURE_READY=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg reference_day "${PACKET_REF_DAY}" \
  --arg executive_signal "${PACKET_SIGNAL}" \
  --arg go_live_status "${PACKET_GO}" \
  --arg day_grade "${DAY_GRADE}" \
  --arg day_status "${DAY_STATUS}" \
  --arg trend "${TREND}" \
  --arg trend_band "${TREND_BAND}" \
  --arg rel_grade "${REL_GRADE}" \
  --arg rel_status "${REL_STATUS}" \
  --arg rel_final "${REL_FINAL}" \
  --arg semaphore_color "${SEM_COLOR}" \
  --arg semaphore_severity "${SEM_SEVERITY}" \
  --arg timeline_final "${TIMELINE_FINAL}" \
  --arg manifest_final "${MANIFEST_FINAL}" \
  --arg packet_file "${LATEST_PACKET}" \
  --arg score_file "${LATEST_SCORE}" \
  --arg trend_file "${LATEST_TREND}" \
  --arg semaphore_file "${LATEST_SEMAPHORE}" \
  --arg reliability_file "${LATEST_RELIABILITY}" \
  --arg timeline_file "${LATEST_TIMELINE}" \
  --arg manifest_file "${LATEST_MANIFEST}" \
  --arg bundle_index_file "${LATEST_BUNDLE_INDEX}" \
  --argjson day_score "${DAY_SCORE}" \
  --argjson rel_score "${REL_SCORE}" \
  --argjson telegram_mute_present "${TELEGRAM_MUTE_PRESENT}" \
  --argjson closure_ready "${CLOSURE_READY}" \
  '{
    created_at: $created_at,
    reference_day: $reference_day,
    executive: {
      executive_signal: $executive_signal,
      go_live_status: $go_live_status,
      semaphore_color: $semaphore_color,
      semaphore_severity: $semaphore_severity
    },
    operational_discipline: {
      score: $day_score,
      grade: $day_grade,
      status: $day_status,
      trend: $trend,
      executive_band: $trend_band
    },
    latest_release: {
      reliability_score: $rel_score,
      reliability_grade: $rel_grade,
      reliability_status: $rel_status,
      final_status: $rel_final,
      timeline_final_status: $timeline_final,
      manifest_final_status: $manifest_final
    },
    governance: {
      telegram_mute_present: $telegram_mute_present,
      closure_ready: $closure_ready
    },
    artifacts: {
      packet_file: $packet_file,
      score_file: $score_file,
      trend_file: $trend_file,
      semaphore_file: $semaphore_file,
      reliability_file: $reliability_file,
      timeline_file: $timeline_file,
      manifest_file: $manifest_file,
      bundle_index_file: $bundle_index_file
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 61 — Fechamento Oficial da Etapa Atual

## Status executivo
- reference_day: ${PACKET_REF_DAY}
- executive_signal: ${PACKET_SIGNAL}
- go_live_status: ${PACKET_GO}
- semaphore: ${SEM_COLOR}/${SEM_SEVERITY}

## Disciplina operacional
- score: ${DAY_SCORE}
- grade: ${DAY_GRADE}
- status: ${DAY_STATUS}
- trend: ${TREND}
- executive_band: ${TREND_BAND}

## Última release
- reliability_score: ${REL_SCORE}
- reliability_grade: ${REL_GRADE}
- reliability_status: ${REL_STATUS}
- final_status: ${REL_FINAL}
- timeline_final_status: ${TIMELINE_FINAL}
- manifest_final_status: ${MANIFEST_FINAL}

## Governança
- telegram_mute_present: ${TELEGRAM_MUTE_PRESENT}
- closure_ready: ${CLOSURE_READY}

## Artefatos-base
- ${LATEST_PACKET}
- ${LATEST_SCORE}
- ${LATEST_TREND}
- ${LATEST_SEMAPHORE}
- ${LATEST_RELIABILITY}
- ${LATEST_TIMELINE}
- ${LATEST_MANIFEST}
- ${LATEST_BUNDLE_INDEX}
MD

echo "[OK] fechamento oficial gerado em ${OUT_JSON}"
echo "[OK] markdown executivo gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
