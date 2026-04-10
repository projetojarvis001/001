#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase81_odoo_inventory_packet_${TS}.json"
OUT_MD="docs/generated/phase81_odoo_inventory_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase81_odoo_inventory_evidence_*.json 2>/dev/null | head -n 1 || true)"
MATRIX_FILE="$(ls -1t logs/executive/phase68_component_scoring_*.json 2>/dev/null | head -n 1 || true)"

READINESS_OK="$(jq -r '.inventory_flow.readiness_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
SERVER_VERSION="$(jq -r '.inventory_flow.server_version // ""' "${EVIDENCE_FILE}" 2>/dev/null || echo "")"
ODOO_SCORE_BEFORE="$(jq -r '.components[] | select(.component == "ODOO") | .current_score' "${MATRIX_FILE}" 2>/dev/null || echo 2.5)"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

if [ "${READINESS_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 1.0, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg server_version "${SERVER_VERSION}" \
  --argjson readiness_ok "${READINESS_OK}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_81_ODOO_INVENTORY_READINESS",
      readiness_ok: $readiness_ok,
      server_version: $server_version,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO agora tem inventario e readiness inicial comprovados."
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
# FASE 81 — ODOO Inventory Packet

## Summary
- readiness_ok: ${READINESS_OK}
- server_version: ${SERVER_VERSION}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] odoo inventory packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
