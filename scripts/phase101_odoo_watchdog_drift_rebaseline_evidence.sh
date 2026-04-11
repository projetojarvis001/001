#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase101_odoo_watchdog_drift_rebaseline_evidence_${TS}.json"
OUT_MD="docs/generated/phase101_odoo_watchdog_drift_rebaseline_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_seed_*.json 2>/dev/null | head -n 1 || true)"
CAPTURE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_capture_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_probe_*.json 2>/dev/null | head -n 1 || true)"

CAPTURE_OK=false
PROBE_OK=false

jq -e '.drift_rebaseline.overall_ok == true' "${CAPTURE_FILE}" >/dev/null && CAPTURE_OK=true || true
jq -e '.drift_rebaseline_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null && PROBE_OK=true || true

FLOW_OK=false
if [ "${CAPTURE_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg capture_file "${CAPTURE_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson capture_ok "${CAPTURE_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    drift_rebaseline_flow: {
      seed_file: $seed_file,
      capture_file: $capture_file,
      probe_file: $probe_file,
      capture_ok: $capture_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 101 — ODOO Drift Rebaseline Evidence

## Flow
- capture_ok: ${CAPTURE_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift rebaseline evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
