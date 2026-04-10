#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RUNNER_FILE="$(ls -1t logs/executive/phase92_odoo_watchdog_runner_*.json 2>/dev/null | head -n 1 || true)"
ARTIFACT_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_artifact_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase92_odoo_scheduler_trace_${TS}.json"
OUT_MD="docs/generated/phase92_odoo_scheduler_trace_${TS}.md"

FLOW_OK="$(jq -r '.runner.flow_ok' "${RUNNER_FILE}")"
SCHEDULER_READY="$(jq -r '.scheduler_artifact.scheduler_ready' "${ARTIFACT_FILE}")"

TRACE_OK=false
if [ "${FLOW_OK}" = "true" ] && [ "${SCHEDULER_READY}" = "true" ]; then
  TRACE_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg runner_file "${RUNNER_FILE}" \
  --arg artifact_file "${ARTIFACT_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson scheduler_ready "${SCHEDULER_READY}" \
  --argjson trace_ok "${TRACE_OK}" \
  '{
    created_at: $created_at,
    scheduler_trace: {
      runner_file: $runner_file,
      artifact_file: $artifact_file,
      flow_ok: $flow_ok,
      scheduler_ready: $scheduler_ready,
      trace_ok: $trace_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 92 — ODOO Scheduler Trace

## Trace
- runner_file: ${RUNNER_FILE}
- artifact_file: ${ARTIFACT_FILE}
- flow_ok: ${FLOW_OK}
- scheduler_ready: ${SCHEDULER_READY}
- trace_ok: ${TRACE_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] scheduler trace gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
