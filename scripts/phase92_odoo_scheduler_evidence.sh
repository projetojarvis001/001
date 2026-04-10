#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
SEED_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_seed_*.json 2>/dev/null | head -n 1 || true)"
RUNNER_FILE="$(ls -1t logs/executive/phase92_odoo_watchdog_runner_*.json 2>/dev/null | head -n 1 || true)"
ARTIFACT_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_artifact_*.json 2>/dev/null | head -n 1 || true)"
TRACE_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_trace_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase92_odoo_scheduler_evidence_${TS}.json"
OUT_MD="docs/generated/phase92_odoo_scheduler_evidence_${TS}.md"

FLOW_OK="$(jq -r '.runner.flow_ok' "${RUNNER_FILE}")"
SCHEDULER_READY="$(jq -r '.scheduler_artifact.scheduler_ready' "${ARTIFACT_FILE}")"
TRACE_OK="$(jq -r '.scheduler_trace.trace_ok' "${TRACE_FILE}")"

EVIDENCE_OK=false
if [ "${FLOW_OK}" = "true" ] && [ "${SCHEDULER_READY}" = "true" ] && [ "${TRACE_OK}" = "true" ]; then
  EVIDENCE_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg runner_file "${RUNNER_FILE}" \
  --arg artifact_file "${ARTIFACT_FILE}" \
  --arg trace_file "${TRACE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson scheduler_ready "${SCHEDULER_READY}" \
  --argjson trace_ok "${TRACE_OK}" \
  --argjson evidence_ok "${EVIDENCE_OK}" \
  '{
    created_at: $created_at,
    scheduler_flow: {
      seed_file: $seed_file,
      runner_file: $runner_file,
      artifact_file: $artifact_file,
      trace_file: $trace_file,
      flow_ok: $flow_ok,
      scheduler_ready: $scheduler_ready,
      trace_ok: $trace_ok,
      evidence_ok: $evidence_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 92 — ODOO Scheduler Evidence

## Flow
- flow_ok: ${FLOW_OK}
- scheduler_ready: ${SCHEDULER_READY}
- trace_ok: ${TRACE_OK}
- evidence_ok: ${EVIDENCE_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] scheduler evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
