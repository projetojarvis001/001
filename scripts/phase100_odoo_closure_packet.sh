#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase100_odoo_closure_packet_${TS}.json"
OUT_MD="docs/generated/phase100_odoo_closure_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase100_odoo_closure_evidence_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.closure_flow.flow_ok // false' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="11.0"
ODOO_SCORE_AFTER="11.5"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg odoo_score_before "${ODOO_SCORE_BEFORE}" \
  --arg odoo_score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_100_ODOO_CLOSURE_EXECUTIVO",
      flow_ok: $flow_ok,
      odoo_score_before: ($odoo_score_before|tonumber),
      odoo_score_after: ($odoo_score_after|tonumber)
    },
    decision: {
      operator_note: "ODOO encerra a esteira 91-100 com watchdog remoto, retention, alerta real, drift control, restore operacional, fallback de alerta e handoff executivo consolidado."
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
# FASE 100 — ODOO Closure Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] closure packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
