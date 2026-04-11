#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase96_odoo_webhook_rotation_seed_${TS}.json"
OUT_MD="docs/generated/phase96_odoo_webhook_rotation_seed_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_URL:?}"
: "${ODOO_DB:?}"
: "${ODOO_ALERT_WEBHOOK:?}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${ODOO_HOST}" \
  --arg port "${ODOO_PORT}" \
  --arg ssh_user "${ODOO_SSH_USER}" \
  --arg url "${ODOO_URL}" \
  --arg db "${ODOO_DB}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      ssh_user: $ssh_user,
      url: $url,
      db: $db,
      objective: "provar rotacao segura do webhook remoto do watchdog do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 96 — ODOO Webhook Rotation Seed

## Target
- host: ${ODOO_HOST}
- port: ${ODOO_PORT}
- ssh_user: ${ODOO_SSH_USER}
- url: ${ODOO_URL}
- db: ${ODOO_DB}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] webhook rotation seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
