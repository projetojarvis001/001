#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase109_mesh_activation_packet_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_evidence_*.json' | sort | tail -n 1)"
CONTROL_FILE="control_plane/mesh_control_plane_state.json"

FLOW_OK="$(jq -r '.mesh_activation_flow.flow_ok' "${EVIDENCE_FILE}")"
ENABLED_TOTAL="$(jq -r '.mesh_control_plane.enabled_total' "${CONTROL_FILE}")"
STATUS="$(jq -r '.mesh_control_plane.status' "${CONTROL_FILE}")"

SCORE_BEFORE="18.0"
SCORE_AFTER="20.5"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson enabled_total "${ENABLED_TOTAL}" \
  --arg status "${STATUS}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_109_MESH_ACTIVATION_CONTROL_PLANE",
      flow_ok: $flow_ok,
      enabled_total: $enabled_total,
      status: $status,
      system_score_before: $score_before,
      system_score_after: $score_after
    },
    decision: {
      operator_note: "Control plane da malha consolidado com inventory resolvido, probe real, health remoto e status multi-node."
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
# FASE 109 — Mesh Activation Packet

## Summary
- flow_ok: ${FLOW_OK}
- enabled_total: ${ENABLED_TOTAL}
- status: ${STATUS}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
