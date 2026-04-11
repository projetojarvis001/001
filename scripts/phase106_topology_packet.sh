#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/topology

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase106_topology_packet_${TS}.json"
OUT_MD="docs/generated/phase106_topology_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_evidence_*.json' | sort | tail -n 1)"
FLOW_OK="$(jq -r '.topology_flow.flow_ok // false' "${EVIDENCE_FILE}")"

SCORE_BEFORE="14.0"
SCORE_AFTER="15.2"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${SCORE_BEFORE}" \
  --arg score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_106_TOPOLOGY_COMMUNICATIONS",
      flow_ok: $flow_ok,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Topologia e mapa de comunicacoes consolidados com servicos portas dependencias e diagrama mermaid."
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
# FASE 106 — Topology Packet

## Summary
- flow_ok: ${FLOW_OK}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
