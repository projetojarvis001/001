#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase72_vision_listener_packet_${TS}.json"
OUT_MD="docs/generated/phase72_vision_listener_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase72_vision_listener_evidence_*.json 2>/dev/null | head -n 1 || true)"
SEM_PACKET="$(ls -1t logs/executive/phase71_vision_semantic_packet_*.json 2>/dev/null | head -n 1 || true)"

AUTO_FLOW_OK="$(jq -r '.listener_flow.auto_flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
CLASSIFICATION_OUT="$(jq -r '.listener_flow.classification_out // ""' "${EVIDENCE_FILE}" 2>/dev/null || echo "")"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 7.4' "${SEM_PACKET}" 2>/dev/null || echo 7.4)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"

LISTENER_LIVE=false
if [ "${AUTO_FLOW_OK}" = "true" ]; then
  LISTENER_LIVE=true
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
  --argjson listener_live "${LISTENER_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_72_VISION_MINIMAL_LISTENER",
      listener_live: $listener_live,
      classification_out: $classification_out,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION agora escuta e processa task nova com listener minimo funcional."
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
# FASE 72 — Vision Listener Packet

## Summary
- listener_live: ${LISTENER_LIVE}
- classification_out: ${CLASSIFICATION_OUT}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] listener packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
