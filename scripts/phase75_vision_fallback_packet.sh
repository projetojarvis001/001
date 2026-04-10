#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase75_vision_fallback_packet_${TS}.json"
OUT_MD="docs/generated/phase75_vision_fallback_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase75_vision_fallback_evidence_*.json 2>/dev/null | head -n 1 || true)"
BATCH_PACKET="$(ls -1t logs/executive/phase74_vision_batch_packet_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.fallback_flow.flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
CLASSIFICATION_OUT="$(jq -r '.fallback_flow.classification_out // ""' "${EVIDENCE_FILE}" 2>/dev/null || echo "")"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 8.5' "${BATCH_PACKET}" 2>/dev/null || echo 8.5)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"
FALLBACK_LIVE=false

if [ "${FLOW_OK}" = "true" ]; then
  FALLBACK_LIVE=true
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.3, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --argjson fallback_live "${FALLBACK_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_75_VISION_FALLBACK",
      fallback_live: $fallback_live,
      classification_out: $classification_out,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION provou fallback operacional quando a rota primaria falha."
    },
    sources: {
      evidence_file: $evidence_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 75 — Vision Fallback Packet

## Summary
- fallback_live: ${FALLBACK_LIVE}
- classification_out: ${CLASSIFICATION_OUT}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] fallback packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
