#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase90_odoo_monitoring_seed_${TS}.json"
OUT_MD="docs/generated/phase90_odoo_monitoring_seed_${TS}.md"

HOST="${ODOO_HOST}"
PORT="${ODOO_PORT}"
URL="${ODOO_URL}"
DB="${ODOO_DB}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${HOST}" \
  --arg port "${PORT}" \
  --arg url "${URL}" \
  --arg db "${DB}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      url: $url,
      db: $db,
      objective: "provar monitoring e alert readiness do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 90 — ODOO Monitoring Seed

## Target
- host: ${HOST}
- port: ${PORT}
- url: ${URL}
- db: ${DB}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] monitoring seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
