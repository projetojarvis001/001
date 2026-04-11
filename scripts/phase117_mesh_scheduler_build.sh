#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RUN_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_run_*.json' | sort | tail -n 1)"

OUT_STATE="scheduler/mesh_scheduler_state.json"
OUT_JSON="logs/executive/phase117_mesh_scheduler_build_${TS}.json"
OUT_MD="docs/generated/phase117_mesh_scheduler_build_${TS}.md"

DONE_COUNT="$(jq -r '.mesh_scheduler_run.done_count' "${RUN_FILE}")"
RETRY_COUNT_TOTAL="$(jq -r '.mesh_scheduler_run.retry_count' "${RUN_FILE}")"
DEAD_COUNT="$(jq -r '.mesh_scheduler_run.dead_count' "${RUN_FILE}")"
RUN_OK="$(jq -r '.mesh_scheduler_run.overall_ok' "${RUN_FILE}")"

STATUS="scheduler_partial"
if [ "${RUN_OK}" = "true" ] && [ "${DONE_COUNT}" = "3" ] && [ "${DEAD_COUNT}" = "0" ]; then
  STATUS="scheduler_operational"
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg run_file "${RUN_FILE}" \
  --arg status "${STATUS}" \
  --argjson done_count "${DONE_COUNT}" \
  --argjson retry_count "${RETRY_COUNT_TOTAL}" \
  --argjson dead_count "${DEAD_COUNT}" \
  --argjson run_ok "${RUN_OK}" \
  '{
    created_at: $created_at,
    mesh_scheduler_state: {
      run_file: $run_file,
      done_count: $done_count,
      retry_count: $retry_count,
      dead_count: $dead_count,
      run_ok: $run_ok,
      status: $status,
      overall_ok: $run_ok
    }
  }' > "${OUT_STATE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg state_file "${OUT_STATE}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    mesh_scheduler_build: {
      state_file: $state_file,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 117 — Mesh Scheduler Build

## Build
- state_file: ${OUT_STATE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase117 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
