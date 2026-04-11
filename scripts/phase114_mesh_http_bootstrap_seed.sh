#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_seed_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_seed_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg created_at "$CREATED_AT" \
  '{
    created_at: $created_at,
    seed: {
      objective: "subir endpoint http real de health em vision e friday e comprovar http reachability da malha"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 114 — Mesh HTTP Bootstrap Seed

## Objetivo
- subir endpoint http real de health em vision e friday e comprovar http reachability da malha

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase114 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
