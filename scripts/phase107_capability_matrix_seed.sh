#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/capability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase107_capability_matrix_seed_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "medir o ecossistema jarvis por matriz de capacidades reais e score executivo 0 a 100"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 107 — Capability Matrix Seed

## Objetivo
- medir o ecossistema jarvis por matriz de capacidades reais e score executivo 0 a 100

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
