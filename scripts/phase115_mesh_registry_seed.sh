#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_JSON="logs/executive/phase115_mesh_registry_seed_${TS}.json"
OUT_MD="docs/generated/phase115_mesh_registry_seed_${TS}.md"

jq -n \
  --arg created_at "${CREATED_AT}" \
  '{
    created_at: $created_at,
    seed: {
      objective: "implantar registro distribuido da malha com heartbeat e identidade operacional dos nos"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 115 — Mesh Registry Seed

## Objetivo
- implantar registro distribuido da malha com heartbeat e identidade operacional dos nos

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase115 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
