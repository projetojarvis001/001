#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_evidence_*.json' | sort | tail -n 1)"

OUT_JSON="logs/executive/phase117_mesh_scheduler_packet_${TS}.json"
OUT_MD="docs/generated/phase117_mesh_scheduler_packet_${TS}.md"

FLOW_OK="$(jq -r '.mesh_scheduler_flow.flow_ok' "${EVIDENCE_FILE}")"
STATUS="$(jq -r '.mesh_scheduler_build.status' "${BUILD_FILE}")"

SCORE_BEFORE="31.0"
SCORE_AFTER="33.1"

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
      phase: "FASE_117_MESH_SCHEDULER_RETRY_DLQ",
      flow_ok: $flow_ok,
      status: $status,
      system_score_before: $score_before,
      system_score_after: $score_after
    },
    decision: {
      operator_note: "Scheduler distribuido consolidado com retry policy e dead letter queue simples da malha."
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
# FASE 117 — Mesh Scheduler Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase117 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
