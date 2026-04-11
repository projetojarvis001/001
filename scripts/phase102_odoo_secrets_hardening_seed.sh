#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase102_odoo_secrets_hardening_seed_${TS}.json"
OUT_MD="docs/generated/phase102_odoo_secrets_hardening_seed_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    seed: {
      objective: "higienizar segredos e consolidar operacao segura do watchdog remoto do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 102 — ODOO Secrets Hardening Seed

## Objetivo
- higienizar segredos e consolidar operacao segura do watchdog remoto do odoo

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase102 seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
