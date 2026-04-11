#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase99_odoo_alert_fallback_seed_${TS}.json"
OUT_MD="docs/generated/phase99_odoo_alert_fallback_seed_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${ODOO_HOST}" \
  --arg port "${ODOO_PORT}" \
  --arg ssh_user "${ODOO_SSH_USER}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      ssh_user: $ssh_user,
      objective: "provar fallback operacional de alerta do watchdog remoto do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 99 — ODOO Alert Fallback Seed

## Target
- host: ${ODOO_HOST}
- port: ${ODOO_PORT}
- ssh_user: ${ODOO_SSH_USER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] fallback seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
