#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase97_odoo_watchdog_drift_evidence_${TS}.json"
OUT_MD="docs/generated/phase97_odoo_watchdog_drift_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_seed_*.json 2>/dev/null | head -n 1 || true)"
BASELINE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_baseline_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_probe_*.json 2>/dev/null | head -n 1 || true)"

BASELINE_OK="$(jq -r '.drift_baseline.last_json_ok // false' "${BASELINE_FILE}")"
PROBE_OK="$(jq -r '.drift_probe.overall_ok // false' "${PROBE_FILE}")"

FLOW_OK=false
if [ "${BASELINE_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg baseline_file "${BASELINE_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson baseline_ok "${BASELINE_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    drift_flow: {
      seed_file: $seed_file,
      baseline_file: $baseline_file,
      probe_file: $probe_file,
      baseline_ok: $baseline_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 97 — ODOO Watchdog Drift Evidence

## Flow
- baseline_ok: ${BASELINE_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
