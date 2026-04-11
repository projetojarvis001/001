#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/dashboard

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase105_executive_dashboard_seed_${TS}.json"
OUT_MD="docs/generated/phase105_executive_dashboard_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "consolidar dashboard executivo de status das maquinas servicos portas banco observabilidade e odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 105 — Executive Dashboard Seed

## Objetivo
- consolidar dashboard executivo de status das maquinas servicos portas banco observabilidade e odoo

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase105 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
