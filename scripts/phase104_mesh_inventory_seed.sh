#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase104_mesh_inventory_seed_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "consolidar inventario vivo da malha jarvis vision friday tadash com status portas servicos e reachability"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 104 — Mesh Inventory Seed

## Objetivo
- consolidar inventario vivo da malha jarvis vision friday tadash com status portas servicos e reachability

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
