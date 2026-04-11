#!/usr/bin/env bash
set -euo pipefail

mkdir -p control_plane runtime/control_plane logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase110_mesh_runtime_build_${TS}.json"
OUT_MD="docs/generated/phase110_mesh_runtime_build_${TS}.md"
OUT_STATE="control_plane/mesh_runtime_state.json"

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_apply_*.json' | sort | tail -n 1 || true)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_probe_*.json' | sort | tail -n 1 || true)"

APPLY_OK=false
PROBE_OK=false
HAS_PLACEHOLDER=false
STATUS="unknown"

if [ -n "${APPLY_FILE}" ]; then
  jq -e '.mesh_runtime_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null 2>&1 && APPLY_OK=true || true
  jq -e '.mesh_runtime_apply.has_placeholder == true' "${APPLY_FILE}" >/dev/null 2>&1 && HAS_PLACEHOLDER=true || true
fi

if [ -n "${PROBE_FILE}" ]; then
  jq -e '.mesh_runtime_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null 2>&1 && PROBE_OK=true || true
fi

if [ "${HAS_PLACEHOLDER}" = true ]; then
  STATUS="pending_external_inputs"
elif [ "${APPLY_OK}" = true ] && [ "${PROBE_OK}" = true ]; then
  STATUS="multi_node_runtime_active"
elif [ "${APPLY_OK}" = true ] || [ "${PROBE_OK}" = true ]; then
  STATUS="multi_node_partial"
else
  STATUS="runtime_not_ready"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg status "${STATUS}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson has_placeholder "${HAS_PLACEHOLDER}" \
  '{
    created_at: $created_at,
    mesh_runtime_state: {
      apply_file: $apply_file,
      probe_file: $probe_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      has_placeholder: $has_placeholder,
      status: $status,
      overall_ok: ($apply_ok or $probe_ok or $has_placeholder)
    }
  }' > "${OUT_STATE}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg state_file "${OUT_STATE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    mesh_runtime_build: {
      state_file: $state_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 110 — Mesh Runtime Build

## Build
- state_file: ${OUT_STATE}
- apply_file: ${APPLY_FILE}
- probe_file: ${PROBE_FILE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase110 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] runtime state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
