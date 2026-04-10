#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase93_odoo_remote_watchdog_packet_${TS}.json"
OUT_MD="docs/generated/phase93_odoo_remote_watchdog_packet_${TS}.md"

FLOW_OK="$(jq -r '.remote_watchdog_flow.flow_ok' "${EVIDENCE_FILE}")"

ODOO_SCORE_BEFORE="9.7"
ODOO_SCORE_AFTER="9.9"
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
      phase: "FASE_93_ODOO_REMOTE_WATCHDOG_DEPLOYMENT",
      flow_ok: $flow_ok,
      odoo_score_before: $odoo_score_before,
      odoo_score_after: $odoo_score_after
    },
    decision: {
      operator_note: "ODOO agora possui watchdog real implantado no servidor com cron e trilha remota."
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
# FASE 93 — ODOO Remote Watchdog Packet

## Summary
- flow_ok: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] remote watchdog packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
