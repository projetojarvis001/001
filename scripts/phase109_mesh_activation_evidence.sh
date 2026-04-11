#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase109_mesh_activation_evidence_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_seed_*.json' | sort | tail -n 1)"
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_inventory_render_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_probe_*.json' | sort | tail -n 1)"
HEALTH_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_remote_health_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_build_*.json' | sort | tail -n 1)"

INV_OK="$(jq -r '.inventory_render.overall_ok' "${INV_FILE}")"
PROBE_OK="$(jq -r '.mesh_activation_probe.overall_ok' "${PROBE_FILE}")"
HEALTH_OK="$(jq -r '.remote_health.overall_ok' "${HEALTH_FILE}")"
BUILD_OK="$(jq -r '.mesh_activation_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
[ "${INV_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ] && FLOW_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg inventory_file "${INV_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg health_file "${HEALTH_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson inventory_ok "${INV_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson health_ok "${HEALTH_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_activation_flow: {
      seed_file: $seed_file,
      inventory_file: $inventory_file,
      probe_file: $probe_file,
      health_file: $health_file,
      build_file: $build_file,
      inventory_ok: $inventory_ok,
      probe_ok: $probe_ok,
      health_ok: $health_ok,
      build_ok: $build_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 109 — Mesh Activation Evidence

## Flow
- inventory_ok: ${INV_OK}
- probe_ok: ${PROBE_OK}
- health_ok: ${HEALTH_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
