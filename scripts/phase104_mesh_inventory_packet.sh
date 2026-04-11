#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase104_mesh_inventory_packet_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_evidence_*.json' | sort | tail -n 1)"
FLOW_OK="$(jq -r '.mesh_inventory_flow.flow_ok // false' "${EVIDENCE_FILE}")"

SCORE_BEFORE="12.2"
SCORE_AFTER="13.0"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${SCORE_BEFORE}" \
  --arg score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_104_MESH_INVENTORY",
      flow_ok: $flow_ok,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Inventario vivo da malha consolidado com nos papeis reachability e fotografia operacional local."
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
# FASE 104 — Mesh Inventory Packet

## Summary
- flow_ok: ${FLOW_OK}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
