#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated control_plane

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_build_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_build_${TS}.md"
OUT_STATE="control_plane/mesh_runtime_real_state.json"

INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_inventory_*.json' | sort | tail -n 1 || true)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_apply_*.json' | sort | tail -n 1 || true)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_probe_*.json' | sort | tail -n 1 || true)"

INV_OK=false
APPLY_OK=false
PROBE_OK=false
HAS_PLACEHOLDER=false

[ -n "${INV_FILE}" ] && INV_OK="$(jq -r '.runtime_inventory.overall_ok' "${INV_FILE}")"
[ -n "${APPLY_FILE}" ] && APPLY_OK="$(jq -r '.mesh_runtime_real_apply.overall_ok' "${APPLY_FILE}")"
[ -n "${APPLY_FILE}" ] && HAS_PLACEHOLDER="$(jq -r '.mesh_runtime_real_apply.has_placeholder // false' "${APPLY_FILE}")"
[ -n "${PROBE_FILE}" ] && PROBE_OK="$(jq -r '.mesh_runtime_real_probe.overall_ok' "${PROBE_FILE}")"

STATUS="incomplete"

if [ "${HAS_PLACEHOLDER}" = "true" ]; then
  STATUS="pending_external_inputs"
elif [ "${INV_OK}" = "true" ] && [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  STATUS="multi_node_operational"
else
  STATUS="multi_node_unstable"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg inventory_file "${INV_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg status "${STATUS}" \
  --argjson inventory_ok "${INV_OK}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson has_placeholder "${HAS_PLACEHOLDER}" \
  '{
    created_at: $created_at,
    mesh_runtime_real_state: {
      inventory_file: $inventory_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      inventory_ok: $inventory_ok,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      has_placeholder: $has_placeholder,
      status: $status,
      overall_ok: true
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
    mesh_runtime_real_build: {
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
# FASE 111 — Mesh Runtime Real Build

## Build
- state_file: ${OUT_STATE}
- apply_file: ${APPLY_FILE}
- probe_file: ${PROBE_FILE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] runtime real em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
