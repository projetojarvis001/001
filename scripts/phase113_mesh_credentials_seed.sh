#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase113_mesh_credentials_seed_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_credentials_seed_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg created_at "${CREATED_AT}" \
  '{
    created_at: $created_at,
    seed: {
      objective: "sanear credenciais reais da malha e validar conectividade efetiva de vision friday tadash"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 113 — Mesh Credentials Seed

## Objetivo
- sanear credenciais reais da malha e validar conectividade efetiva de vision friday tadash

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
