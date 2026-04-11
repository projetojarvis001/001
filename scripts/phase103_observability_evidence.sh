#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/observability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase103_observability_evidence_${TS}.json"
OUT_MD="docs/generated/phase103_observability_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase103_observability_seed_*.json 2>/dev/null | head -n 1 || true)"
APPLY_FILE="$(ls -1t logs/executive/phase103_observability_apply_*.json 2>/dev/null | head -n 1 || true)"
PROBE_FILE="$(ls -1t logs/executive/phase103_observability_probe_*.json 2>/dev/null | head -n 1 || true)"

APPLY_OK=false
PROBE_OK=false

jq -e '.observability_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null && APPLY_OK=true || true
jq -e '.observability_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null && PROBE_OK=true || true

FLOW_OK=false
if [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    observability_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 103 — Observability Evidence

## Flow
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase103 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
