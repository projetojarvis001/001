#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/topology

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase106_topology_seed_${TS}.json"
OUT_MD="docs/generated/phase106_topology_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "mapear topologia de servicos portas comunicacoes e dependencias do ecossistema jarvis"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 106 — Topology Seed

## Objetivo
- mapear topologia de servicos portas comunicacoes e dependencias do ecossistema jarvis

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
