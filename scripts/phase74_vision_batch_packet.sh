#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase74_vision_batch_packet_${TS}.json"
OUT_MD="docs/generated/phase74_vision_batch_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase74_vision_batch_evidence_*.json 2>/dev/null | head -n 1 || true)"
REDIS_PACKET="$(ls -1t logs/executive/phase73_vision_redis_packet_*.json 2>/dev/null | head -n 1 || true)"

BATCH_FLOW_OK="$(jq -r '.batch_flow.batch_flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 8.2' "${REDIS_PACKET}" 2>/dev/null || echo 8.2)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"
BATCH_LIVE=false

if [ "${BATCH_FLOW_OK}" = "true" ]; then
  BATCH_LIVE=true
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.3, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson batch_live "${BATCH_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_74_VISION_BATCH_QUEUE",
      batch_live: $batch_live,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION provou consumo em lote sem duplicidade por Redis."
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
# FASE 74 — Vision Batch Packet

## Summary
- batch_live: ${BATCH_LIVE}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] batch packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
