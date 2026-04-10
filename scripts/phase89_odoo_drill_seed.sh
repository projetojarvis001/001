#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase89_odoo_drill_seed_${TS}.json"
OUT_MD="docs/generated/phase89_odoo_drill_seed_${TS}.md"

HOST="${ODOO_HOST}"
PORT="${ODOO_PORT}"
URL="${ODOO_URL}"
DB="${ODOO_DB}"
DRILL_DB="${ODOO_DB}_drill_${TS}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "${HOST}" \
  --arg port "${PORT}" \
  --arg url "${URL}" \
  --arg db "${DB}" \
  --arg drill_db "${DRILL_DB}" \
  '{
    created_at: $created_at,
    seed: {
      host: $host,
      port: $port,
      url: $url,
      db: $db,
      drill_db: $drill_db,
      objective: "provar disaster recovery drill controlado do odoo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 89 — ODOO DR Drill Seed

## Target
- host: ${HOST}
- port: ${PORT}
- url: ${URL}
- db: ${DB}
- drill_db: ${DRILL_DB}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drill seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
