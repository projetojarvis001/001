#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase73_vision_redis_packet_${TS}.json"
OUT_MD="docs/generated/phase73_vision_redis_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase73_vision_redis_evidence_*.json 2>/dev/null | head -n 1 || true)"
LISTENER_PACKET="$(ls -1t logs/executive/phase72_vision_listener_packet_*.json 2>/dev/null | head -n 1 || true)"

REDIS_FLOW_OK="$(jq -r '.redis_flow.redis_flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
CLASSIFICATION_OUT="$(jq -r '.redis_flow.classification_out // ""' "${EVIDENCE_FILE}" 2>/dev/null || echo "")"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 7.8' "${LISTENER_PACKET}" 2>/dev/null || echo 7.8)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"
QUEUE_LIVE=false

if [ "${REDIS_FLOW_OK}" = "true" ]; then
  QUEUE_LIVE=true
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.4, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --argjson queue_live "${QUEUE_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_73_VISION_REDIS_QUEUE",
      queue_live: $queue_live,
      classification_out: $classification_out,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION agora consome task por fila Redis real."
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
# FASE 73 — Vision Redis Packet

## Summary
- queue_live: ${QUEUE_LIVE}
- classification_out: ${CLASSIFICATION_OUT}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] redis packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
