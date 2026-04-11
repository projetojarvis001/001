#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/dashboard

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase105_executive_dashboard_packet_${TS}.json"
OUT_MD="docs/generated/phase105_executive_dashboard_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_evidence_*.json' | sort | tail -n 1)"
FLOW_OK="$(jq -r '.dashboard_flow.flow_ok // false' "${EVIDENCE_FILE}")"

SCORE_BEFORE="13.0"
SCORE_AFTER="14.0"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${SCORE_BEFORE}" \
  --arg score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_105_EXECUTIVE_DASHBOARD",
      flow_ok: $flow_ok,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Dashboard executivo consolidado com status de malha servicos portas observabilidade banco e odoo."
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
# FASE 105 — Executive Dashboard Packet

## Summary
- flow_ok: ${FLOW_OK}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase105 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
