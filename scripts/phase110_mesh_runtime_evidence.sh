#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase110_mesh_runtime_evidence_${TS}.json"
OUT_MD="docs/generated/phase110_mesh_runtime_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_seed_*.json' | sort | tail -n 1 || true)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_apply_*.json' | sort | tail -n 1 || true)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_probe_*.json' | sort | tail -n 1 || true)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase110_mesh_runtime_build_*.json' | sort | tail -n 1 || true)"

APPLY_OK=false
PROBE_OK=false
BUILD_OK=false
PENDING_INPUTS=false
FLOW_OK=false

[ -n "${APPLY_FILE}" ] && jq -e '.mesh_runtime_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null 2>&1 && APPLY_OK=true || true
[ -n "${PROBE_FILE}" ] && jq -e '.mesh_runtime_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null 2>&1 && PROBE_OK=true || true
[ -n "${BUILD_FILE}" ] && jq -e '.mesh_runtime_build.overall_ok == true' "${BUILD_FILE}" >/dev/null 2>&1 && BUILD_OK=true || true
[ -n "${BUILD_FILE}" ] && jq -e '.mesh_runtime_build.status == "pending_external_inputs"' "${BUILD_FILE}" >/dev/null 2>&1 && PENDING_INPUTS=true || true

if [ "${BUILD_OK}" = true ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson pending_inputs "${PENDING_INPUTS}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_runtime_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      build_file: $build_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      build_ok: $build_ok,
      pending_external_inputs: $pending_inputs,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 110 — Mesh Runtime Evidence

## Flow
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- pending_external_inputs: ${PENDING_INPUTS}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase110 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
