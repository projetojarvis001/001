#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase112_mesh_readiness_inventory_check_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_inventory_check_${TS}.md"
RAW_FILE="runtime/readiness/phase112_mesh_readiness_inventory_check_${TS}.txt"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

INV_FILE="inventory/nodes.resolved.yml"

{
  echo "===== INVENTORY CHECK ====="
  echo "INV_FILE=${INV_FILE}"
  [ -f "${INV_FILE}" ] && sed -n '1,260p' "${INV_FILE}"
} > "${RAW_FILE}"

INV_EXISTS=false
[ -f "${INV_FILE}" ] && INV_EXISTS=true

PLACEHOLDER_FOUND=false
grep -q 'COLE_AQUI' "${INV_FILE}" 2>/dev/null && PLACEHOLDER_FOUND=true

NODES_TOTAL="$(grep -c '^- name:' "${INV_FILE}" 2>/dev/null || true)"
[ -z "${NODES_TOTAL}" ] && NODES_TOTAL=0

OVERALL_OK=false
if [ "${INV_EXISTS}" = true ]; then
  OVERALL_OK=true
fi

jq -n \
  --arg created_at "${created_at}" \
  --arg raw_file "${RAW_FILE}" \
  --arg inv_file "${INV_FILE}" \
  --argjson inv_exists "${INV_EXISTS}" \
  --argjson placeholder_found "${PLACEHOLDER_FOUND}" \
  --argjson nodes_total "${NODES_TOTAL}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    inventory_check: {
      raw_file: $raw_file,
      inv_file: $inv_file,
      inv_exists: $inv_exists,
      placeholder_found: $placeholder_found,
      nodes_total: $nodes_total,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 112 — Mesh Readiness Inventory Check

## Inventory
- raw_file: ${RAW_FILE}
- inv_file: ${INV_FILE}
- inv_exists: ${INV_EXISTS}
- placeholder_found: ${PLACEHOLDER_FOUND}
- nodes_total: ${NODES_TOTAL}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 inventory check gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
