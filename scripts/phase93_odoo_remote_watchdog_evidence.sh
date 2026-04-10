#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
SEED_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_seed_*.json 2>/dev/null | head -n 1 || true)"
DEPLOY_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_deploy_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_probe_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase93_odoo_remote_watchdog_evidence_${TS}.json"
OUT_MD="docs/generated/phase93_odoo_remote_watchdog_evidence_${TS}.md"

CRON_OK="$(jq -r '.remote_watchdog_deploy.cron_ok' "${DEPLOY_FILE}")"
RUN_OK="$(jq -r '.remote_watchdog_deploy.run_ok' "${DEPLOY_FILE}")"
STAMP_OK="$(jq -r '.remote_watchdog_deploy.stamp_ok' "${DEPLOY_FILE}")"
PROBE_OK="$(jq -r '.remote_watchdog_probe.overall_ok' "${PROBE_FILE}")"

FLOW_OK=false
if [ "${CRON_OK}" = "true" ] && [ "${RUN_OK}" = "true" ] && [ "${STAMP_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg deploy_file "${DEPLOY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson cron_ok "${CRON_OK}" \
  --argjson run_ok "${RUN_OK}" \
  --argjson stamp_ok "${STAMP_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    remote_watchdog_flow: {
      seed_file: $seed_file,
      deploy_file: $deploy_file,
      probe_file: $probe_file,
      cron_ok: $cron_ok,
      run_ok: $run_ok,
      stamp_ok: $stamp_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 93 — ODOO Remote Watchdog Evidence

## Flow
- cron_ok: ${CRON_OK}
- run_ok: ${RUN_OK}
- stamp_ok: ${STAMP_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] remote watchdog evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
