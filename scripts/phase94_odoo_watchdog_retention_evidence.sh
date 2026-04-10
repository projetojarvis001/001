#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase94_odoo_watchdog_retention_evidence_${TS}.json"
OUT_MD="docs/generated/phase94_odoo_watchdog_retention_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_seed_*.json 2>/dev/null | head -n 1 || true)"
APPLY_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_apply_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_probe_*.json 2>/dev/null | head -n 1 || true)"

SCRIPT_OK="$(jq -r '.retention_apply.script_ok' "${APPLY_FILE}")"
CRON_OK="$(jq -r '.retention_apply.cron_ok' "${APPLY_FILE}")"
RUN_OK="$(jq -r '.retention_apply.run_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.retention_probe.overall_ok' "${PROBE_FILE}")"

FLOW_OK=false
[ "${SCRIPT_OK}" = "true" ] && [ "${CRON_OK}" = "true" ] && [ "${RUN_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && FLOW_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson script_ok "${SCRIPT_OK}" \
  --argjson cron_ok "${CRON_OK}" \
  --argjson run_ok "${RUN_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    retention_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      script_ok: $script_ok,
      cron_ok: $cron_ok,
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
# FASE 94 — ODOO Watchdog Retention Evidence

## Flow
- script_ok: ${SCRIPT_OK}
- cron_ok: ${CRON_OK}
- run_ok: ${RUN_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] retention evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
