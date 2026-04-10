#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase82_odoo_hardening_packet_${TS}.json"
OUT_MD="docs/generated/phase82_odoo_hardening_packet_${TS}.md"

RISK_FILE="$(ls -1t logs/executive/phase82_odoo_risk_assessment_*.json 2>/dev/null | head -n 1 || true)"
PACKET81="$(ls -1t logs/executive/phase81_odoo_inventory_packet_*.json 2>/dev/null | head -n 1 || true)"

RISK_LEVEL="$(jq -r '.risk.risk_level // ""' "${RISK_FILE}" 2>/dev/null || echo "")"
RISK_SCORE="$(jq -r '.risk.risk_score // 0' "${RISK_FILE}" 2>/dev/null || echo 0)"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 3.5' "${PACKET81}" 2>/dev/null || echo 3.5)"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg risk_file "${RISK_FILE}" \
  --arg risk_level "${RISK_LEVEL}" \
  --argjson risk_score "${RISK_SCORE}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_82_ODOO_HARDENING_RISK",
      risk_level: $risk_level,
      risk_score: $risk_score,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO agora tem superficie de risco mapeada para endurecimento controlado."
    },
    sources: {
      risk_file: $risk_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 82 — ODOO Hardening Packet

## Summary
- risk_level: ${RISK_LEVEL}
- risk_score: ${RISK_SCORE}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] hardening packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
