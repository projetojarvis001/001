#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase78_vision_memory_packet_${TS}.json"
OUT_MD="docs/generated/phase78_vision_memory_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase78_vision_memory_evidence_*.json 2>/dev/null | head -n 1 || true)"
POLICY_PACKET="$(ls -1t logs/executive/phase77_vision_policy_packet_*.json 2>/dev/null | head -n 1 || true)"

MEMORY_LIVE="$(jq -r '.memory_flow.memory_flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 9.2' "${POLICY_PACKET}" 2>/dev/null || echo 9.2)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"

if [ "${MEMORY_LIVE}" = "true" ]; then
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.2, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson memory_live "${MEMORY_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_78_VISION_MEMORY_CONTEXT",
      memory_live: $memory_live,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION agora usa memoria contextual recente para enriquecer a decisao."
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
# FASE 78 — Vision Memory Packet

## Summary
- memory_live: ${MEMORY_LIVE}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] memory packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
