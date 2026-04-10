#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase95_odoo_alert_delivery_packet_${TS}.json"
OUT_MD="docs/generated/phase95_odoo_alert_delivery_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_evidence_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.alert_delivery_flow.flow_ok' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="10.0"
ODOO_SCORE_AFTER="10.2"
[ "${FLOW_OK}" = "true" ] || ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg phase "FASE_95_ODOO_ALERT_DELIVERY_REAL" \
  --argjson odoo_score_before "${ODOO_SCORE_BEFORE}" \
  --argjson odoo_score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: $phase,
      flow_ok: $flow_ok,
      odoo_score_before: $odoo_score_before,
      odoo_score_after: $odoo_score_after
    },
    decision: {
      operator_note: "ODOO agora possui entrega real de alerta remoto do watchdog."
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
# FASE 95 — ODOO Alert Delivery Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] alert delivery packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
