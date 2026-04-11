#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/capability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase107_capability_matrix_snapshot_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_snapshot_${TS}.md"

OBS_FILE="$(find logs/executive -maxdepth 1 -name 'phase103_observability_packet_*.json' | sort | tail -n 1)"
MESH_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_packet_*.json' | sort | tail -n 1)"
DASH_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_packet_*.json' | sort | tail -n 1)"
TOPO_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_packet_*.json' | sort | tail -n 1)"
DRIFT_FILE="$(find logs/executive -maxdepth 1 -name 'phase101_odoo_watchdog_drift_rebaseline_packet_*.json' | sort | tail -n 1)"
FALLBACK_FILE="$(find logs/executive -maxdepth 1 -name 'phase99_odoo_alert_fallback_packet_*.json' | sort | tail -n 1)"
RESTORE_FILE="$(find logs/executive -maxdepth 1 -name 'phase98_odoo_watchdog_restore_packet_*.json' | sort | tail -n 1)"
CLOSURE_FILE="$(find logs/executive -maxdepth 1 -name 'phase100_odoo_closure_packet_*.json' | sort | tail -n 1)"

OBS_OK=false
MESH_OK=false
DASH_OK=false
TOPO_OK=false
DRIFT_OK=false
FALLBACK_OK=false
RESTORE_OK=false
CLOSURE_OK=false

jq -e '.summary.flow_ok == true' "${OBS_FILE}" >/dev/null && OBS_OK=true || true
jq -e '.summary.flow_ok == true' "${MESH_FILE}" >/dev/null && MESH_OK=true || true
jq -e '.summary.flow_ok == true' "${DASH_FILE}" >/dev/null && DASH_OK=true || true
jq -e '.summary.flow_ok == true' "${TOPO_FILE}" >/dev/null && TOPO_OK=true || true
jq -e '.summary.flow_ok == true' "${DRIFT_FILE}" >/dev/null && DRIFT_OK=true || true
jq -e '.summary.flow_ok == true' "${FALLBACK_FILE}" >/dev/null && FALLBACK_OK=true || true
jq -e '.summary.flow_ok == true' "${RESTORE_FILE}" >/dev/null && RESTORE_OK=true || true
jq -e '.summary.flow_ok == true' "${CLOSURE_FILE}" >/dev/null && CLOSURE_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg obs_file "${OBS_FILE}" \
  --arg mesh_file "${MESH_FILE}" \
  --arg dash_file "${DASH_FILE}" \
  --arg topo_file "${TOPO_FILE}" \
  --arg drift_file "${DRIFT_FILE}" \
  --arg fallback_file "${FALLBACK_FILE}" \
  --arg restore_file "${RESTORE_FILE}" \
  --arg closure_file "${CLOSURE_FILE}" \
  --argjson obs_ok "${OBS_OK}" \
  --argjson mesh_ok "${MESH_OK}" \
  --argjson dash_ok "${DASH_OK}" \
  --argjson topo_ok "${TOPO_OK}" \
  --argjson drift_ok "${DRIFT_OK}" \
  --argjson fallback_ok "${FALLBACK_OK}" \
  --argjson restore_ok "${RESTORE_OK}" \
  --argjson closure_ok "${CLOSURE_OK}" \
  '{
    created_at: $created_at,
    capability_snapshot: {
      observability_file: $obs_file,
      mesh_file: $mesh_file,
      dashboard_file: $dash_file,
      topology_file: $topo_file,
      drift_file: $drift_file,
      fallback_file: $fallback_file,
      restore_file: $restore_file,
      closure_file: $closure_file,
      observability_ok: $obs_ok,
      mesh_ok: $mesh_ok,
      dashboard_ok: $dash_ok,
      topology_ok: $topo_ok,
      drift_ok: $drift_ok,
      fallback_ok: $fallback_ok,
      restore_ok: $restore_ok,
      closure_ok: $closure_ok,
      overall_ok: ($obs_ok and $mesh_ok and $dash_ok and $topo_ok and $drift_ok and $fallback_ok and $restore_ok and $closure_ok)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 107 — Capability Matrix Snapshot

## Snapshot
- observability_ok: ${OBS_OK}
- mesh_ok: ${MESH_OK}
- dashboard_ok: ${DASH_OK}
- topology_ok: ${TOPO_OK}
- drift_ok: ${DRIFT_OK}
- fallback_ok: ${FALLBACK_OK}
- restore_ok: ${RESTORE_OK}
- closure_ok: ${CLOSURE_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
