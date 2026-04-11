#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_seed_*.json' | sort | tail -n 1)"
QUEUE_FILE_JSON="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_queue_*.json' | sort | tail -n 1)"
RUN_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_run_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_build_*.json' | sort | tail -n 1)"

OUT_JSON="logs/executive/phase117_mesh_scheduler_evidence_${TS}.json"
OUT_MD="docs/generated/phase117_mesh_scheduler_evidence_${TS}.md"

QUEUE_OK="$(jq -r '.scheduler_queue.overall_ok' "${QUEUE_FILE_JSON}")"
RUN_OK="$(jq -r '.mesh_scheduler_run.overall_ok' "${RUN_FILE}")"
BUILD_OK="$(jq -r '.mesh_scheduler_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
if [ "${QUEUE_OK}" = "true" ] && [ "${RUN_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg seed_file "${SEED_FILE}" \
  --arg queue_file "${QUEUE_FILE_JSON}" \
  --arg run_file "${RUN_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson queue_ok "${QUEUE_OK}" \
  --argjson run_ok "${RUN_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_scheduler_flow: {
      seed_file: $seed_file,
      queue_file: $queue_file,
      run_file: $run_file,
      build_file: $build_file,
      queue_ok: $queue_ok,
      run_ok: $run_ok,
      build_ok: $build_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 117 — Mesh Scheduler Evidence

## Flow
- queue_ok: ${QUEUE_OK}
- run_ok: ${RUN_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase117 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
