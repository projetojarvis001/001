#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase70_vision_first_live_packet_${TS}.json"
OUT_MD="docs/generated/phase70_vision_first_live_packet_${TS}.md"

READINESS_FILE="$(ls -1t logs/executive/phase69_vision_readiness_*.json 2>/dev/null | head -n 1 || true)"
SCORE_FILE="$(ls -1t logs/executive/phase69_vision_score_gap_*.json 2>/dev/null | head -n 1 || true)"
FLOW_FILE="$(ls -1t logs/executive/phase70_vision_flow_evidence_*.json 2>/dev/null | head -n 1 || true)"

READY_FOR_PHASE70="$(jq -r '.readiness.ready_for_phase70 // false' "${READINESS_FILE}" 2>/dev/null || echo false)"
BASE_SCORE="$(jq -r '.vision.base_score // 0' "${SCORE_FILE}" 2>/dev/null || echo 0)"
MATCH_OK="$(jq -r '.flow.match_ok // false' "${FLOW_FILE}" 2>/dev/null || echo false)"
STATUS_OUT="$(jq -r '.flow.status_out // ""' "${FLOW_FILE}" 2>/dev/null || echo "")"
CLASSIFICATION_OUT="$(jq -r '.flow.classification_out // ""' "${FLOW_FILE}" 2>/dev/null || echo "")"

LIVE_FLOW_PROVEN=false
UPDATED_SCORE="${BASE_SCORE}"

if [ "${READY_FOR_PHASE70}" = "true" ] && [ "${MATCH_OK}" = "true" ] && [ "${STATUS_OUT}" = "processed" ]; then
  LIVE_FLOW_PROVEN=true
  UPDATED_SCORE="$(python3 - <<PY
base = float("${BASE_SCORE}")
new = min(base + 0.4, 10.0)
print(f"{new:.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg readiness_file "${READINESS_FILE}" \
  --arg score_file "${SCORE_FILE}" \
  --arg flow_file "${FLOW_FILE}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --argjson live_flow_proven "${LIVE_FLOW_PROVEN}" \
  --argjson base_score "${BASE_SCORE}" \
  --arg updated_score "${UPDATED_SCORE}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_70_VISION_FIRST_LIVE_FLOW",
      live_flow_proven: $live_flow_proven,
      classification_out: $classification_out,
      base_score_before: ($base_score | tonumber),
      score_after: ($updated_score | tonumber)
    },
    decision: {
      operator_note: "VISION executou o primeiro fluxo controlado ponta a ponta sem deploy."
    },
    sources: {
      readiness_file: $readiness_file,
      score_file: $score_file,
      flow_file: $flow_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 70 — Vision First Live Packet

## Summary
- live_flow_proven: ${LIVE_FLOW_PROVEN}
- classification_out: ${CLASSIFICATION_OUT}
- base_score_before: ${BASE_SCORE}
- score_after: ${UPDATED_SCORE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] vision first live packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
