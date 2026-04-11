#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/topology

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase106_topology_evidence_${TS}.json"
OUT_MD="docs/generated/phase106_topology_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_seed_*.json' | sort | tail -n 1)"
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_snapshot_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_build_*.json' | sort | tail -n 1)"
MERMAID_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_mermaid_*.json' | sort | tail -n 1)"

SNAP_OK=false
BUILD_OK=false
MERMAID_OK=false

jq -e '.topology_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null && SNAP_OK=true || true
jq -e '.topology_build.overall_ok == true' "${BUILD_FILE}" >/dev/null && BUILD_OK=true || true
jq -e '.topology_mermaid.overall_ok == true' "${MERMAID_FILE}" >/dev/null && MERMAID_OK=true || true

FLOW_OK=false
if [ "${SNAP_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ] && [ "${MERMAID_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --arg mermaid_file "${MERMAID_FILE}" \
  --argjson snapshot_ok "${SNAP_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson mermaid_ok "${MERMAID_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    topology_flow: {
      seed_file: $seed_file,
      snapshot_file: $snapshot_file,
      build_file: $build_file,
      mermaid_file: $mermaid_file,
      snapshot_ok: $snapshot_ok,
      build_ok: $build_ok,
      mermaid_ok: $mermaid_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 106 — Topology Evidence

## Flow
- snapshot_ok: ${SNAP_OK}
- build_ok: ${BUILD_OK}
- mermaid_ok: ${MERMAID_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
