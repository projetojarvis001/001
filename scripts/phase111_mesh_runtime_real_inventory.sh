#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/control_plane inventory

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase111_mesh_runtime_real_inventory_${TS}.txt"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_inventory_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_inventory_${TS}.md"
OUT_INV="inventory/nodes.runtime.yml"

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

envsubst < inventory/nodes.yml > "${OUT_INV}"

{
  echo "===== INVENTORY RUNTIME ====="
  cat "${OUT_INV}"
} > "${RAW_FILE}"

INV_OK=false
grep -q 'IP_OU_HOST_REAL' "${OUT_INV}" && INV_OK=false || INV_OK=true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg inventory_file "${OUT_INV}" \
  --argjson inventory_ok "${INV_OK}" \
  '{
    created_at: $created_at,
    runtime_inventory: {
      raw_file: $raw_file,
      inventory_file: $inventory_file,
      inventory_ok: $inventory_ok,
      overall_ok: $inventory_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 111 — Mesh Runtime Real Inventory

## Inventory
- raw_file: ${RAW_FILE}
- inventory_file: ${OUT_INV}
- inventory_ok: ${INV_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 inventory gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
