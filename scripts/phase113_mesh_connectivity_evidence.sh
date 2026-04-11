#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase113_mesh_connectivity_evidence_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_connectivity_evidence_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_credentials_seed_*.json' | sort | tail -n 1)"
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_credentials_snapshot_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_build_*.json' | sort | tail -n 1)"

SNAP_OK="$(jq -r '.credentials_snapshot.overall_ok' "${SNAP_FILE}")"
PROBE_OK="$(jq -r '.connectivity_probe.overall_ok' "${PROBE_FILE}")"
BUILD_OK="$(jq -r '.connectivity_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
if [ "${SNAP_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg seed_file "${SEED_FILE}" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --argjson snapshot_ok "${SNAP_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_connectivity_flow: {
      seed_file: $seed_file,
      snapshot_file: $snapshot_file,
      probe_file: $probe_file,
      build_file: $build_file,
      snapshot_ok: $snapshot_ok,
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
# FASE 113 — Mesh Connectivity Evidence

## Flow
- snapshot_ok: ${SNAP_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
