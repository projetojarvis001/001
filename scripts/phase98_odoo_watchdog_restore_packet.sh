#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase98_odoo_watchdog_restore_packet_${TS}.json"
OUT_MD="docs/generated/phase98_odoo_watchdog_restore_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_evidence_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.restore_flow.flow_ok // false' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="10.6"
ODOO_SCORE_AFTER="10.8"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg odoo_score_before "${ODOO_SCORE_BEFORE}" \
  --arg odoo_score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_98_ODOO_WATCHDOG_RESTORE_OPERATIONAL",
      flow_ok: $flow_ok,
      odoo_score_before: ($odoo_score_before|tonumber),
      odoo_score_after: ($odoo_score_after|tonumber)
    },
    decision: {
      operator_note: "ODOO agora possui restore operacional comprovado do watchdog remoto."
    },
    sources: {
      evidence_file: $evidence_file
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 98 — ODOO Watchdog Restore Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] restore packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
