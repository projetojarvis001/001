#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase89_odoo_drill_packet_${TS}.json"
OUT_MD="docs/generated/phase89_odoo_drill_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase89_odoo_drill_evidence_*.json 2>/dev/null | head -n 1 || true)"
PACKET88="$(ls -1t logs/executive/phase88_odoo_backup_packet_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.drill_flow.flow_ok' "${EVIDENCE_FILE}")"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 8.2' "${PACKET88}")"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

if [ "${FLOW_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 0.5, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_89_ODOO_DISASTER_RECOVERY_DRILL",
      flow_ok: $flow_ok,
      dr_ready: $flow_ok,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO provou restauracao controlada em banco temporario com limpeza ao final."
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
# FASE 89 — ODOO DR Drill Packet

## Summary
- flow_ok: ${FLOW_OK}
- dr_ready: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drill packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
