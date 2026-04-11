#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_evidence_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_seed_*.json' | sort | tail -n 1 || true)"
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_inventory_*.json' | sort | tail -n 1 || true)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_apply_*.json' | sort | tail -n 1 || true)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_probe_*.json' | sort | tail -n 1 || true)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_build_*.json' | sort | tail -n 1 || true)"

INV_OK=false
APPLY_OK=false
PROBE_OK=false
BUILD_OK=false
PENDING_INPUTS=false
FLOW_OK=false

[ -n "${INV_FILE}" ] && INV_OK="$(jq -r '.runtime_inventory.overall_ok' "${INV_FILE}")"
[ -n "${APPLY_FILE}" ] && APPLY_OK="$(jq -r '.mesh_runtime_real_apply.overall_ok' "${APPLY_FILE}")"
[ -n "${PROBE_FILE}" ] && PROBE_OK="$(jq -r '.mesh_runtime_real_probe.overall_ok' "${PROBE_FILE}")"
[ -n "${BUILD_FILE}" ] && BUILD_OK="$(jq -r '.mesh_runtime_real_build.overall_ok' "${BUILD_FILE}")"
[ -n "${BUILD_FILE}" ] && [ "$(jq -r '.mesh_runtime_real_build.status' "${BUILD_FILE}")" = "pending_external_inputs" ] && PENDING_INPUTS=true || true

if [ "${INV_OK}" = "true" ] && [ "${APPLY_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg inventory_file "${INV_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson inventory_ok "${INV_OK}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson pending_external_inputs "${PENDING_INPUTS}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_runtime_real_flow: {
      seed_file: $seed_file,
      inventory_file: $inventory_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      build_file: $build_file,
      inventory_ok: $inventory_ok,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      build_ok: $build_ok,
      pending_external_inputs: $pending_external_inputs,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 111 — Mesh Runtime Real Evidence

## Flow
- inventory_ok: ${INV_OK}
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- pending_external_inputs: ${PENDING_INPUTS}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
