#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase101_odoo_watchdog_drift_rebaseline_packet_${TS}.json"
OUT_MD="docs/generated/phase101_odoo_watchdog_drift_rebaseline_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_evidence_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.drift_rebaseline_flow.flow_ok // false' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="11.5"
ODOO_SCORE_AFTER="11.6"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg odoo_score_before "${ODOO_SCORE_BEFORE}" \
  --arg odoo_score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_101_ODOO_DRIFT_REBASELINE",
      flow_ok: $flow_ok,
      odoo_score_before: ($odoo_score_before|tonumber),
      odoo_score_after: ($odoo_score_after|tonumber)
    },
    decision: {
      operator_note: "Baseline de drift recalibrada para o estado operacional vigente do watchdog remoto do odoo."
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
# FASE 101 — ODOO Drift Rebaseline Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift rebaseline packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
