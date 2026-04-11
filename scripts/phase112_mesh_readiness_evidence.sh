#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase112_mesh_readiness_evidence_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_evidence_${TS}.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_snapshot_*.json' | sort | tail -n 1)"
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_inventory_check_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_build_*.json' | sort | tail -n 1)"
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_report_*.json' | sort | tail -n 1)"

SNAP_OK="$(jq -r '.readiness_snapshot.overall_ok' "${SNAP_FILE}")"
INV_OK="$(jq -r '.inventory_check.overall_ok' "${INV_FILE}")"
BUILD_OK="$(jq -r '.readiness_build.overall_ok' "${BUILD_FILE}")"
REPORT_OK="$(jq -r '.readiness_report.overall_ok' "${REPORT_FILE}")"

FLOW_OK=false
if [ "${SNAP_OK}" = "true" ] && [ "${INV_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ] && [ "${REPORT_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "${created_at}" \
  --arg seed_file "$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_seed_*.json' | sort | tail -n 1)" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg inventory_file "${INV_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --arg report_file "${REPORT_FILE}" \
  --argjson snapshot_ok "${SNAP_OK}" \
  --argjson inventory_ok "${INV_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson report_ok "${REPORT_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_readiness_flow: {
      seed_file: $seed_file,
      snapshot_file: $snapshot_file,
      inventory_file: $inventory_file,
      build_file: $build_file,
      report_file: $report_file,
      snapshot_ok: $snapshot_ok,
      inventory_ok: $inventory_ok,
      build_ok: $build_ok,
      report_ok: $report_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 112 — Mesh Readiness Evidence

## Flow
- snapshot_ok: ${SNAP_OK}
- inventory_ok: ${INV_OK}
- build_ok: ${BUILD_OK}
- report_ok: ${REPORT_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
