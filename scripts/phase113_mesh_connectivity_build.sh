#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p readiness logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_STATE="readiness/mesh_connectivity_state.json"
OUT_JSON="logs/executive/phase113_mesh_connectivity_build_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_connectivity_build_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_credentials_snapshot_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_probe_*.json' | sort | tail -n 1)"

PLACEHOLDER_COUNT="$(jq -r '.credentials_snapshot.placeholder_count' "${SNAP_FILE}")"
READY_COUNT="$(jq -r '.connectivity_probe.ready_count' "${PROBE_FILE}")"

STATUS="blocked"
if [ "${PLACEHOLDER_COUNT}" = "0" ] && [ "${READY_COUNT}" = "3" ]; then
  STATUS="fully_ready"
elif [ "${PLACEHOLDER_COUNT}" = "0" ] && [ "${READY_COUNT}" -ge 1 ]; then
  STATUS="partially_ready"
elif [ "${PLACEHOLDER_COUNT}" = "0" ]; then
  STATUS="credentials_ok_but_connectivity_failed"
else
  STATUS="blocked_by_placeholders"
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson placeholder_count "${PLACEHOLDER_COUNT}" \
  --argjson ready_count "${READY_COUNT}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    mesh_connectivity: {
      snapshot_file: $snapshot_file,
      probe_file: $probe_file,
      placeholder_count: $placeholder_count,
      ready_count: $ready_count,
      status: $status,
      overall_ok: true
    }
  }' > "${OUT_STATE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg state_file "${OUT_STATE}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    connectivity_build: {
      state_file: $state_file,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 113 — Mesh Connectivity Build

## Build
- state_file: ${OUT_STATE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] connectivity state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
