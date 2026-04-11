#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/capability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase107_capability_matrix_evidence_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_seed_*.json' | sort | tail -n 1)"
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_snapshot_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_build_*.json' | sort | tail -n 1)"
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_report_*.json' | sort | tail -n 1)"

SNAP_OK=false
BUILD_OK=false
REPORT_OK=false

jq -e '.capability_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null && SNAP_OK=true || true
jq -e '.capability_matrix_build.overall_ok == true' "${BUILD_FILE}" >/dev/null && BUILD_OK=true || true
jq -e '.capability_report.overall_ok == true' "${REPORT_FILE}" >/dev/null && REPORT_OK=true || true

FLOW_OK=false
if [ "${SNAP_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ] && [ "${REPORT_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg build_file "${BUILD_FILE}" \
  --arg report_file "${REPORT_FILE}" \
  --argjson snapshot_ok "${SNAP_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson report_ok "${REPORT_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    capability_flow: {
      seed_file: $seed_file,
      snapshot_file: $snapshot_file,
      build_file: $build_file,
      report_file: $report_file,
      snapshot_ok: $snapshot_ok,
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
# FASE 107 — Capability Matrix Evidence

## Flow
- snapshot_ok: ${SNAP_OK}
- build_ok: ${BUILD_OK}
- report_ok: ${REPORT_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
