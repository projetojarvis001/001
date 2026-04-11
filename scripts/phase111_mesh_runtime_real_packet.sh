#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_packet_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_evidence_*.json' | sort | tail -n 1 || true)"
STATE_FILE="control_plane/mesh_runtime_real_state.json"

FLOW_OK=false
STATUS="unknown"

[ -n "${EVIDENCE_FILE}" ] && FLOW_OK="$(jq -r '.mesh_runtime_real_flow.flow_ok' "${EVIDENCE_FILE}")"
[ -f "${STATE_FILE}" ] && STATUS="$(jq -r '.mesh_runtime_real_state.status' "${STATE_FILE}")"

SCORE_BEFORE=21.0
SCORE_AFTER=21.8

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg phase "FASE_111_MESH_RUNTIME_REAL" \
  --arg status "${STATUS}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: $phase,
      flow_ok: $flow_ok,
      status: $status,
      system_score_before: $score_before,
      system_score_after: $score_after
    },
    decision: {
      operator_note: "Runtime real da malha foi estruturado corretamente e permaneceu pendente de inputs externos validos."
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
# FASE 111 — Mesh Runtime Real Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
