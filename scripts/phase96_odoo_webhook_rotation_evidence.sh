#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase96_odoo_webhook_rotation_evidence_${TS}.json"
OUT_MD="docs/generated/phase96_odoo_webhook_rotation_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase96_odoo_webhook_rotation_seed_*.json 2>/dev/null | head -n 1 || true)"
APPLY_FILE="$(ls -1t logs/executive/phase96_odoo_webhook_rotation_apply_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase96_odoo_webhook_rotation_probe_*.json 2>/dev/null | head -n 1 || true)"

ENV_OK="$(jq -r '.webhook_rotation_apply.env_ok // false' "${APPLY_FILE}")"
BACKUP_OK="$(jq -r '.webhook_rotation_apply.backup_ok // false' "${APPLY_FILE}")"
RUN_OK="$(jq -r '.webhook_rotation_apply.run_ok // false' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.webhook_rotation_probe.overall_ok // false' "${PROBE_FILE}")"

FLOW_OK=false
if [ "${ENV_OK}" = "true" ] && [ "${BACKUP_OK}" = "true" ] && [ "${RUN_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson env_ok "${ENV_OK}" \
  --argjson backup_ok "${BACKUP_OK}" \
  --argjson run_ok "${RUN_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    webhook_rotation_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      env_ok: $env_ok,
      backup_ok: $backup_ok,
      run_ok: $run_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 96 — ODOO Webhook Rotation Evidence

## Flow
- env_ok: ${ENV_OK}
- backup_ok: ${BACKUP_OK}
- run_ok: ${RUN_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] webhook rotation evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
