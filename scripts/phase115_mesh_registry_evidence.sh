#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_seed_*.json' | sort | tail -n 1)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_build_*.json' | sort | tail -n 1)"

OUT_JSON="logs/executive/phase115_mesh_registry_evidence_${TS}.json"
OUT_MD="docs/generated/phase115_mesh_registry_evidence_${TS}.md"

APPLY_OK="$(jq -r '.mesh_registry_apply.overall_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.mesh_registry_probe.overall_ok' "${PROBE_FILE}")"
BUILD_OK="$(jq -r '.mesh_registry_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
if [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg seed_file "${SEED_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_registry_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      build_file: $build_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      build_ok: $build_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 115 — Mesh Registry Evidence

## Flow
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase115 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
