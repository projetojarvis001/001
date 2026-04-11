#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/control_plane

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_seed_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "ativar conectividade real da malha e comprovar bootstrap minimo dos nos vision friday tadash"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 111 — Mesh Runtime Real Seed

## Objetivo
- ativar conectividade real da malha e comprovar bootstrap minimo dos nos vision friday tadash

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
