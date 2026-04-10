#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase95_odoo_alert_delivery_evidence_${TS}.json"
OUT_MD="docs/generated/phase95_odoo_alert_delivery_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_seed_*.json 2>/dev/null | head -n 1 || true)"
DEPLOY_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_deploy_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_probe_*.json 2>/dev/null | head -n 1 || true)"

SCRIPT_OK="$(jq -r '.alert_delivery_deploy.script_ok' "${DEPLOY_FILE}")"
TEST_OK="$(jq -r '.alert_delivery_deploy.test_ok' "${DEPLOY_FILE}")"
PROBE_OK="$(jq -r '.alert_delivery_probe.overall_ok' "${PROBE_FILE}")"

FLOW_OK=false
[ "${SCRIPT_OK}" = "true" ] && [ "${TEST_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && FLOW_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg deploy_file "${DEPLOY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson script_ok "${SCRIPT_OK}" \
  --argjson test_ok "${TEST_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    alert_delivery_flow: {
      seed_file: $seed_file,
      deploy_file: $deploy_file,
      probe_file: $probe_file,
      script_ok: $script_ok,
      test_ok: $test_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 95 — ODOO Alert Delivery Evidence

## Flow
- script_ok: ${SCRIPT_OK}
- test_ok: ${TEST_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] alert delivery evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
