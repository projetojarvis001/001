#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase108_decision_engine_evidence_${TS}.json"
OUT_MD="docs/generated/phase108_decision_engine_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_seed_*.json' | sort | tail -n 1)"
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_snapshot_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_build_*.json' | sort | tail -n 1)"
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_report_*.json' | sort | tail -n 1)"

SNAP_OK="$(jq -r '.decision_snapshot.overall_ok' "${SNAP_FILE}")"
BUILD_OK="$(jq -r '.decision_engine_build.overall_ok' "${BUILD_FILE}")"
REPORT_OK="$(jq -r '.decision_engine_report.overall_ok' "${REPORT_FILE}")"

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
    decision_engine_flow: {
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
# FASE 108 — Decision Engine Evidence

## Flow
- snapshot_ok: ${SNAP_OK}
- build_ok: ${BUILD_OK}
- report_ok: ${REPORT_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase108 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
