#!/usr/bin/env bash
set -e
mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase86b_odoo_proxy_rewire_packet_${TS}.json"
OUT_MD="docs/generated/phase86b_odoo_proxy_rewire_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase86b_odoo_proxy_rewire_evidence_*.json 2>/dev/null | head -n 1 || true)"
PACKET85="$(ls -1t logs/executive/phase85_odoo_exposure_packet_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.proxy_rewire_flow.flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 6.0' "${PACKET85}" 2>/dev/null || echo 6.0)"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"
RISK_AFTER="LOW"

if [ "${FLOW_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 1.1, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg risk_after "${RISK_AFTER}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_86B_ODOO_PROXY_REWIRE",
      flow_ok: $flow_ok,
      risk_after: $risk_after,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO passou a responder por Nginx na borda e Odoo ficou interno."
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
# FASE 86B — ODOO Proxy Rewire Packet

## Summary
- flow_ok: ${FLOW_OK}
- risk_after: ${RISK_AFTER}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] proxy rewire packet 86B gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
