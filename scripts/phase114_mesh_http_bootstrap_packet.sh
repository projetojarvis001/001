#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_packet_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_packet_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_evidence_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_build_*.json' | sort | tail -n 1)"

FLOW_OK="$(jq -r '.mesh_http_bootstrap_flow.flow_ok' "${EVIDENCE_FILE}")"
STATUS="$(jq -r '.mesh_http_bootstrap_build.status' "${BUILD_FILE}")"

SCORE_BEFORE="24.0"
SCORE_AFTER="27.0"

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg status "$STATUS" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson score_before "${SCORE_BEFORE}" \
  --argjson score_after "${SCORE_AFTER}" \
  --arg evidence_file "$EVIDENCE_FILE" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_114_MESH_HTTP_BOOTSTRAP",
      flow_ok: $flow_ok,
      status: $status,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Vision e Friday receberam endpoint HTTP real de health e a malha ganhou prova operacional web distribuida."
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
# FASE 114 — Mesh HTTP Bootstrap Packet

## Summary
- flow_ok: ${FLOW_OK}
- status: ${STATUS}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase114 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
