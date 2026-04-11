#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase100_odoo_closure_evidence_${TS}.json"
OUT_MD="docs/generated/phase100_odoo_closure_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase100_odoo_closure_seed_*.json 2>/dev/null | head -n 1 || true)"
INVENTORY_FILE="$(ls -1t logs/executive/phase100_odoo_closure_inventory_*.json 2>/dev/null | head -n 1 || true)"
CONSOLIDATION_FILE="$(ls -1t logs/executive/phase100_odoo_closure_consolidation_*.json 2>/dev/null | head -n 1 || true)"
CHECKLIST_FILE="$(ls -1t logs/executive/phase100_odoo_closure_checklist_*.json 2>/dev/null | head -n 1 || true)"

INVENTORY_OK=false
CONSOLIDATION_OK=false
CHECKLIST_OK=false

jq -e '.closure_inventory.overall_ok == true' "${INVENTORY_FILE}" >/dev/null && INVENTORY_OK=true || true
jq -e '.consolidation.program_ok == true' "${CONSOLIDATION_FILE}" >/dev/null && CONSOLIDATION_OK=true || true
jq -e '.checklist.handoff_ready == true' "${CHECKLIST_FILE}" >/dev/null && CHECKLIST_OK=true || true

FLOW_OK=false
if [ "${INVENTORY_OK}" = "true" ] && [ "${CONSOLIDATION_OK}" = "true" ] && [ "${CHECKLIST_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg inventory_file "${INVENTORY_FILE}" \
  --arg consolidation_file "${CONSOLIDATION_FILE}" \
  --arg checklist_file "${CHECKLIST_FILE}" \
  --argjson inventory_ok "${INVENTORY_OK}" \
  --argjson consolidation_ok "${CONSOLIDATION_OK}" \
  --argjson checklist_ok "${CHECKLIST_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    closure_flow: {
      seed_file: $seed_file,
      inventory_file: $inventory_file,
      consolidation_file: $consolidation_file,
      checklist_file: $checklist_file,
      inventory_ok: $inventory_ok,
      consolidation_ok: $consolidation_ok,
      checklist_ok: $checklist_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 100 — ODOO Closure Evidence

## Flow
- inventory_ok: ${INVENTORY_OK}
- consolidation_ok: ${CONSOLIDATION_OK}
- checklist_ok: ${CHECKLIST_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] closure evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
