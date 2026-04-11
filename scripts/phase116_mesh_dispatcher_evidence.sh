#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_seed_*.json' | sort | tail -n 1)"
MANIFEST_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_manifest_*.json' | sort | tail -n 1)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_build_*.json' | sort | tail -n 1)"

OUT_JSON="logs/executive/phase116_mesh_dispatcher_evidence_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_evidence_${TS}.md"

MANIFEST_OK="$(jq -r '.dispatcher_manifest.overall_ok' "${MANIFEST_FILE}")"
APPLY_OK="$(jq -r '.mesh_dispatcher_apply.overall_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.mesh_dispatcher_probe.overall_ok' "${PROBE_FILE}")"
BUILD_OK="$(jq -r '.mesh_dispatcher_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
if [ "${MANIFEST_OK}" = "true" ] && [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg seed_file "${SEED_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg apply_file "${APPLY_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson manifest_ok "${MANIFEST_OK}" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_dispatcher_flow: {
      seed_file: $seed_file,
      manifest_file: $manifest_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      build_file: $build_file,
      manifest_ok: $manifest_ok,
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
# FASE 116 — Mesh Dispatcher Evidence

## Flow
- manifest_ok: ${MANIFEST_OK}
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase116 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
