#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase86_odoo_reverse_proxy_seed_${TS}.json"
OUT_MD="docs/generated/phase86_odoo_reverse_proxy_seed_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
URL="${ODOO_URL:-}"
DB="${ODOO_DB:-}"

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
      objective: "migrar exposicao do odoo para proxy reverso real"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 86 — ODOO Reverse Proxy Seed

## Target
- host: ${HOST}
- port: ${PORT}
- url: ${URL}
- db: ${DB}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] reverse proxy seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
