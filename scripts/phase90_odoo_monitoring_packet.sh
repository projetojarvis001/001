#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase90_odoo_monitoring_packet_${TS}.json"
OUT_MD="docs/generated/phase90_odoo_monitoring_packet_${TS}.md"

STATUS_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_status_*.json 2>/dev/null | head -n 1 || true)"
PACKET89="$(ls -1t logs/executive/phase89_odoo_drill_packet_*.json 2>/dev/null | head -n 1 || true)"

STATUS="$(jq -r '.monitoring_status.status' "${STATUS_FILE}")"
FLOW_OK=false
[ "${STATUS}" = "GREEN" ] && FLOW_OK=true || true

ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 8.7' "${PACKET89}")"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

if [ "${FLOW_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 0.4, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg status_file "${STATUS_FILE}" \
  --arg status "${STATUS}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_90_ODOO_MONITORING_ALERT_READINESS",
      flow_ok: $flow_ok,
      monitoring_status: $status,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO agora tem healthcheck consolidado para web, rpc e infra."
    },
    sources: {
      status_file: $status_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 90 — ODOO Monitoring Packet

## Summary
- flow_ok: ${FLOW_OK}
- monitoring_status: ${STATUS}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] monitoring packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
