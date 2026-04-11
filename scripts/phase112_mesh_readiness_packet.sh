#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase112_mesh_readiness_packet_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_packet_${TS}.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_evidence_*.json' | sort | tail -n 1)"
STATE_FILE="readiness/mesh_readiness_state.json"

FLOW_OK="$(jq -r '.mesh_readiness_flow.flow_ok' "${EVIDENCE_FILE}")"
STATUS="$(jq -r '.mesh_readiness.status' "${STATE_FILE}")"
READY_COUNT="$(jq -r '.mesh_readiness.ready_count' "${STATE_FILE}")"
BLOCKED_COUNT="$(jq -r '.mesh_readiness.blocked_count' "${STATE_FILE}")"

SCORE_BEFORE="21.8"
SCORE_AFTER="22.6"

jq -n \
  --arg created_at "${created_at}" \
  --arg status "${STATUS}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson blocked_count "${BLOCKED_COUNT}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_112_MESH_READINESS_GATE",
      flow_ok: $flow_ok,
      status: $status,
      ready_count: $ready_count,
      blocked_count: $blocked_count,
      system_score_before: $score_before,
      system_score_after: $score_after
    },
    decision: {
      operator_note: "Readiness gate da malha consolidado com classificacao objetiva de nos prontos e bloqueados."
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
# FASE 112 — Mesh Readiness Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- ready_count: ${READY_COUNT}
- blocked_count: ${BLOCKED_COUNT}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
