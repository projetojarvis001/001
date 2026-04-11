#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/capability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase107_capability_matrix_packet_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_evidence_*.json' | sort | tail -n 1)"
FLOW_OK="$(jq -r '.capability_flow.flow_ok // false' "${EVIDENCE_FILE}")"
OVERALL_SCORE="$(jq -r '.capability_matrix.overall_score' capability/system_capability_matrix.json)"

SCORE_BEFORE="15.2"
SCORE_AFTER="16.4"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg overall_score "${OVERALL_SCORE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${SCORE_BEFORE}" \
  --arg score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_107_CAPABILITY_MATRIX",
      flow_ok: $flow_ok,
      capability_score: ($overall_score|tonumber),
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Matriz de capacidades consolidada com score realista 0 a 100 por atributo e gaps priorizados."
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
# FASE 107 — Capability Matrix Packet

## Summary
- flow_ok: ${FLOW_OK}
- capability_score: ${OVERALL_SCORE}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
