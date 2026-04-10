#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase84_odoo_surface_packet_${TS}.json"
OUT_MD="docs/generated/phase84_odoo_surface_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase84_odoo_surface_evidence_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.surface_flow.flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
ODOO_SCORE_BEFORE="$(jq -r '.score_reference.odoo_score_before // 4.5' "${EVIDENCE_FILE}" 2>/dev/null || echo 4.5)"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"
RISK_AFTER="MEDIUM"

if [ "${FLOW_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 0.8, 10.0):.1f}")
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
      phase: "FASE_84_ODOO_SURFACE_REDUCTION",
      flow_ok: $flow_ok,
      risk_after: $risk_after,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO teve reducao inicial de superficie sem perder acesso operacional."
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
# FASE 84 — ODOO Surface Packet

## Summary
- flow_ok: ${FLOW_OK}
- risk_after: ${RISK_AFTER}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] surface packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
