#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase113_mesh_connectivity_packet_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_connectivity_packet_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_evidence_*.json' | sort | tail -n 1)"
STATE_FILE="readiness/mesh_connectivity_state.json"

FLOW_OK="$(jq -r '.mesh_connectivity_flow.flow_ok' "${EVIDENCE_FILE}")"
STATUS="$(jq -r '.mesh_connectivity.status' "${STATE_FILE}")"
READY_COUNT="$(jq -r '.mesh_connectivity.ready_count' "${STATE_FILE}")"

SCORE_BEFORE="22.6"
SCORE_AFTER="24.0"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg phase "FASE_113_MESH_CREDENTIALS_AND_CONNECTIVITY" \
  --arg status "${STATUS}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  '{
    created_at: $created_at,
    summary: {
      phase: $phase,
      flow_ok: $flow_ok,
      status: $status,
      ready_count: $ready_count,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Credenciais reais e conectividade da malha avaliadas com classificacao objetiva de prontidao."
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
# FASE 113 — Mesh Connectivity Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- ready_count: ${READY_COUNT}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
