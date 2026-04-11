#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_probe_*.json' | sort | tail -n 1)"

OUT_STATE="dispatcher/mesh_dispatcher_state.json"
OUT_JSON="logs/executive/phase116_mesh_dispatcher_build_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_build_${TS}.md"

APPLY_OK="$(jq -r '.mesh_dispatcher_apply.overall_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.mesh_dispatcher_probe.overall_ok' "${PROBE_FILE}")"
READY_COUNT="$(jq -r '.mesh_dispatcher_probe.ready_count' "${PROBE_FILE}")"

STATUS="partial_dispatch"
if [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && [ "${READY_COUNT}" = "3" ]; then
  STATUS="dispatcher_operational"
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg status "${STATUS}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  '{
    created_at: $created_at,
    mesh_dispatcher_state: {
      apply_file: $apply_file,
      probe_file: $probe_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      ready_count: $ready_count,
      status: $status,
      overall_ok: ($apply_ok and $probe_ok)
    }
  }' > "${OUT_STATE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg state_file "${OUT_STATE}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    mesh_dispatcher_build: {
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
# FASE 116 — Mesh Dispatcher Build

## Build
- state_file: ${OUT_STATE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase116 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
