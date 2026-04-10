#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase81_odoo_inventory_seed_${TS}.json"
OUT_MD="docs/generated/phase81_odoo_inventory_seed_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
URL="${ODOO_URL:-}"
DB="${ODOO_DB:-}"

if [ -z "${HOST}" ] || [ -z "${SSH_USER}" ] || [ -z "${URL}" ] || [ -z "${DB}" ]; then
  echo "[ERRO] variaveis de ambiente ODOO incompletas"
  exit 1
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${HOST}" \
  --arg port "${PORT}" \
  --arg ssh_user "${SSH_USER}" \
  --arg url "${URL}" \
  --arg db "${DB}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      ssh_user: $ssh_user,
      url: $url,
      db: $db,
      objective: "provar inventario e readiness real do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 81 — ODOO Inventory Seed

## Alvos
- host: ${HOST}
- port: ${PORT}
- ssh_user: ${SSH_USER}
- url: ${URL}
- db: ${DB}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] odoo inventory seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
