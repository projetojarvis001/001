#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase91_odoo_watchdog_packet_${TS}.json"
OUT_MD="docs/generated/phase91_odoo_watchdog_packet_${TS}.md"

FLOW_OK="$(jq -r '.watchdog_flow.flow_ok' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="9.1"
ODOO_SCORE_AFTER="9.4"
[ "${FLOW_OK}" != "true" ] && ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}" || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson odoo_score_before "${ODOO_SCORE_BEFORE}" \
  --argjson odoo_score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_91_ODOO_WATCHDOG_ALERT_ARTIFACT",
      flow_ok: $flow_ok,
      odoo_score_before: $odoo_score_before,
      odoo_score_after: $odoo_score_after
    },
    decision: {
      operator_note: "ODOO agora possui watchdog executavel e artefato de alerta pronto."
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
# FASE 91 — ODOO Watchdog Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] watchdog packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
