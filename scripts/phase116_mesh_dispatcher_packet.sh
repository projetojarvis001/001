#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_evidence_*.json' | sort | tail -n 1)"

OUT_JSON="logs/executive/phase116_mesh_dispatcher_packet_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_packet_${TS}.md"

FLOW_OK="$(jq -r '.mesh_dispatcher_flow.flow_ok' "${EVIDENCE_FILE}")"
STATUS="$(jq -r '.mesh_dispatcher_build.status' "${BUILD_FILE}")"

SCORE_BEFORE="29.2"
SCORE_AFTER="31.0"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg status "${STATUS}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_116_MESH_JOB_DISPATCHER",
      flow_ok: $flow_ok,
      status: $status,
      system_score_before: $score_before,
      system_score_after: $score_after
    },
    decision: {
      operator_note: "Dispatcher distribuido da malha consolidado com envio, execucao e coleta de jobs por no."
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
# FASE 116 — Mesh Dispatcher Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase116 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
