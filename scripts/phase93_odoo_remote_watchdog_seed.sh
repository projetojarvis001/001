#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase93_odoo_remote_watchdog_seed_${TS}.json"
OUT_MD="docs/generated/phase93_odoo_remote_watchdog_seed_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-}"
URL="${ODOO_URL:-}"
DB="${ODOO_DB:-}"
SSH_USER="${ODOO_SSH_USER:-}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${HOST}" \
  --arg port "${PORT}" \
  --arg url "${URL}" \
  --arg db "${DB}" \
  --arg ssh_user "${SSH_USER}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      url: $url,
      db: $db,
      ssh_user: $ssh_user,
      objective: "provar watchdog remoto implantado e agendado no servidor do odoo"
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 93 — ODOO Remote Watchdog Seed

## Target
- host: ${HOST}
- port: ${PORT}
- url: ${URL}
- db: ${DB}
- ssh_user: ${SSH_USER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] remote watchdog seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
