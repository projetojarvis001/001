#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase89_odoo_drill_evidence_${TS}.json"
OUT_MD="docs/generated/phase89_odoo_drill_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase89_odoo_drill_seed_*.json 2>/dev/null | head -n 1 || true)"
RESTORE_FILE="$(ls -1t logs/executive/phase89_odoo_restore_drill_*.json 2>/dev/null | head -n 1 || true)"
AUTH_FILE="$(ls -1t logs/executive/phase89_odoo_drill_auth_probe_*.json 2>/dev/null | head -n 1 || true)"
CLEANUP_FILE="$(ls -1t logs/executive/phase89_odoo_drill_cleanup_*.json 2>/dev/null | head -n 1 || true)"

RESTORE_OK="$(jq -r '.restore_drill.drill_db_ready' "${RESTORE_FILE}")"
AUTH_OK="$(jq -r '.drill_auth_probe.auth_ok' "${AUTH_FILE}")"
CLEANUP_OK="$(jq -r '.drill_cleanup.db_removed' "${CLEANUP_FILE}")"

FLOW_OK=false
if [ "${RESTORE_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ] && [ "${CLEANUP_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg restore_file "${RESTORE_FILE}" \
  --arg auth_file "${AUTH_FILE}" \
  --arg cleanup_file "${CLEANUP_FILE}" \
  --argjson restore_ok "${RESTORE_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson cleanup_ok "${CLEANUP_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    drill_flow: {
      seed_file: $seed_file,
      restore_file: $restore_file,
      auth_file: $auth_file,
      cleanup_file: $cleanup_file,
      restore_ok: $restore_ok,
      auth_ok: $auth_ok,
      cleanup_ok: $cleanup_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 89 — ODOO Drill Evidence

## Flow
- restore_ok: ${RESTORE_OK}
- auth_ok: ${AUTH_OK}
- cleanup_ok: ${CLEANUP_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drill evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
