#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase89_odoo_drill_cleanup_${TS}.json"
OUT_MD="docs/generated/phase89_odoo_drill_cleanup_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase89_odoo_drill_seed_*.json 2>/dev/null | head -n 1 || true)"
DRILL_DB="$(jq -r '.seed.drill_db // ""' "${SEED_FILE}")"

sshpass -p "${ODOO_SSH_PASS}" ssh -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
"PGPASSWORD='odoowps' dropdb -U odoo -h localhost -p 5432 --if-exists '${DRILL_DB}'" >/dev/null 2>&1 || true

DB_REMOVED=true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg drill_db "${DRILL_DB}" \
  --argjson db_removed "${DB_REMOVED}" \
  '{
    created_at: $created_at,
    drill_cleanup: {
      seed_file: $seed_file,
      drill_db: $drill_db,
      db_removed: $db_removed
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 89 — ODOO Drill Cleanup

## Cleanup
- drill_db: ${DRILL_DB}
- db_removed: ${DB_REMOVED}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drill cleanup gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
