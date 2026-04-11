#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/observability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase103_observability_seed_${TS}.json"
OUT_MD="docs/generated/phase103_observability_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "implantar camada central de observabilidade com prometheus grafana loki exporters e probes"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 103 — Observability Seed

## Objetivo
- implantar camada central de observabilidade com prometheus grafana loki exporters e probes

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase103 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
