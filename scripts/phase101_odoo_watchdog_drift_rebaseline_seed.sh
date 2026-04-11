#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase101_odoo_watchdog_drift_rebaseline_seed_${TS}.json"
OUT_MD="docs/generated/phase101_odoo_watchdog_drift_rebaseline_seed_${TS}.md"

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
      objective: "recalibrar baseline de drift do watchdog remoto do odoo para o estado operacional atual"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 101 — ODOO Drift Rebaseline Seed

## Target
- host: ${ODOO_HOST}
- port: ${ODOO_PORT}
- ssh_user: ${ODOO_SSH_USER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift rebaseline seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
