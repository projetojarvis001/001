#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase99_odoo_alert_fallback_evidence_${TS}.json"
OUT_MD="docs/generated/phase99_odoo_alert_fallback_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_seed_*.json 2>/dev/null | head -n 1 || true)"
APPLY_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_apply_*.json 2>/dev/null | head -n 1 || true)"
DRILL_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_drill_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_probe_*.json 2>/dev/null | head -n 1 || true)"

APPLY_OK=false
DRILL_OK=false
PROBE_OK=false

jq -e '.fallback_apply.script_ok == true and .fallback_apply.backup_ok == true and .fallback_apply.fallback_ok == true' "${APPLY_FILE}" >/dev/null && APPLY_OK=true || true
jq -e '.fallback_drill.overall_ok == true' "${DRILL_FILE}" >/dev/null && DRILL_OK=true || true
jq -e '.fallback_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null && PROBE_OK=true || true

FLOW_OK=false
if [ "${APPLY_OK}" = "true" ] && [ "${DRILL_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg drill_file "${DRILL_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson drill_ok "${DRILL_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    fallback_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      drill_file: $drill_file,
      probe_file: $probe_file,
      apply_ok: $apply_ok,
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
# FASE 99 — ODOO Alert Fallback Evidence

## Flow
- apply_ok: ${APPLY_OK}
- drill_ok: ${DRILL_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] fallback evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
