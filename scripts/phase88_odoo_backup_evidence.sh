#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase88_odoo_backup_evidence_${TS}.json"
OUT_MD="docs/generated/phase88_odoo_backup_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase88_odoo_backup_seed_*.json 2>/dev/null | head -n 1 || true)"
RUN_FILE="$(ls -1t logs/executive/phase88_odoo_backup_run_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/executive/phase88_odoo_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"

DB_DUMP_OK="$(jq -r '.backup_run.db_dump_ok' "${RUN_FILE}")"
ODOO_CONF_OK="$(jq -r '.backup_run.odoo_conf_ok' "${RUN_FILE}")"
NGINX_CONF_OK="$(jq -r '.backup_run.nginx_conf_ok' "${RUN_FILE}")"
RESTORE_READY="$(jq -r '.restore_manifest.restore_ready' "${MANIFEST_FILE}")"

FLOW_OK=false
if [ "${DB_DUMP_OK}" = "true" ] && [ "${ODOO_CONF_OK}" = "true" ] && [ "${NGINX_CONF_OK}" = "true" ] && [ "${RESTORE_READY}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg run_file "${RUN_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --argjson db_dump_ok "${DB_DUMP_OK}" \
  --argjson odoo_conf_ok "${ODOO_CONF_OK}" \
  --argjson nginx_conf_ok "${NGINX_CONF_OK}" \
  --argjson restore_ready "${RESTORE_READY}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    backup_flow: {
      seed_file: $seed_file,
      run_file: $run_file,
      manifest_file: $manifest_file,
      db_dump_ok: $db_dump_ok,
      odoo_conf_ok: $odoo_conf_ok,
      nginx_conf_ok: $nginx_conf_ok,
      restore_ready: $restore_ready,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 88 — ODOO Backup Evidence

## Flow
- db_dump_ok: ${DB_DUMP_OK}
- odoo_conf_ok: ${ODOO_CONF_OK}
- nginx_conf_ok: ${NGINX_CONF_OK}
- restore_ready: ${RESTORE_READY}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] backup evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
