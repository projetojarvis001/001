#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase98_odoo_watchdog_restore_evidence_${TS}.json"
OUT_MD="docs/generated/phase98_odoo_watchdog_restore_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_seed_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"
DRILL_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_drill_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_probe_*.json 2>/dev/null | head -n 1 || true)"

MANIFEST_OK=false
DRILL_OK=false
PROBE_OK=false

jq -e '.restore_manifest.send_ok == true and .restore_manifest.env_ok == true and .restore_manifest.retention_ok == true and .restore_manifest.cron_ok == true' "${MANIFEST_FILE}" >/dev/null && MANIFEST_OK=true || true
jq -e '.restore_drill.overall_ok == true' "${DRILL_FILE}" >/dev/null && DRILL_OK=true || true
jq -e '.restore_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null && PROBE_OK=true || true

FLOW_OK=false
if [ "${MANIFEST_OK}" = "true" ] && [ "${DRILL_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg drill_file "${DRILL_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson manifest_ok "${MANIFEST_OK}" \
  --argjson drill_ok "${DRILL_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    restore_flow: {
      seed_file: $seed_file,
      manifest_file: $manifest_file,
      drill_file: $drill_file,
      probe_file: $probe_file,
      manifest_ok: $manifest_ok,
      drill_ok: $drill_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 98 — ODOO Watchdog Restore Evidence

## Flow
- manifest_ok: ${MANIFEST_OK}
- drill_ok: ${DRILL_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] restore evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
