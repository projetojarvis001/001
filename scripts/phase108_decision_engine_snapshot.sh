#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/decision_engine

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase108_decision_engine_snapshot_${TS}.json"
OUT_MD="docs/generated/phase108_decision_engine_snapshot_${TS}.md"

OBS_FILE="$(find logs/executive -maxdepth 1 -name 'phase103_observability_packet_*.json' | sort | tail -n 1)"
CLOSURE_FILE="$(find logs/executive -maxdepth 1 -name 'phase100_odoo_closure_packet_*.json' | sort | tail -n 1)"
FALLBACK_FILE="$(find logs/executive -maxdepth 1 -name 'phase99_odoo_alert_fallback_packet_*.json' | sort | tail -n 1)"
RESTORE_FILE="$(find logs/executive -maxdepth 1 -name 'phase98_odoo_watchdog_restore_packet_*.json' | sort | tail -n 1)"
MESH_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_consolidation_*.json' | sort | tail -n 1)"
CAP_FILE="capability/system_capability_matrix.json"

OBS_OK=false
CLOSURE_OK=false
FALLBACK_OK=false
RESTORE_OK=false

jq -e '.summary.flow_ok == true' "${OBS_FILE}" >/dev/null && OBS_OK=true || true
jq -e '.summary.flow_ok == true' "${CLOSURE_FILE}" >/dev/null && CLOSURE_OK=true || true
jq -e '.summary.flow_ok == true' "${FALLBACK_FILE}" >/dev/null && FALLBACK_OK=true || true
jq -e '.summary.flow_ok == true' "${RESTORE_FILE}" >/dev/null && RESTORE_OK=true || true

MESH_DEFINED="$(jq -r '.mesh_inventory.nodes_defined' "${MESH_FILE}")"
MESH_ENABLED="$(jq -r '.mesh_inventory.nodes_enabled' "${MESH_FILE}")"
CAP_SCORE="$(jq -r '.capability_matrix.overall_score' "${CAP_FILE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg obs_file "${OBS_FILE}" \
  --arg closure_file "${CLOSURE_FILE}" \
  --arg fallback_file "${FALLBACK_FILE}" \
  --arg restore_file "${RESTORE_FILE}" \
  --arg mesh_file "${MESH_FILE}" \
  --arg cap_file "${CAP_FILE}" \
  --argjson observability_flow_ok "${OBS_OK}" \
  --argjson odoo_closure_ok "${CLOSURE_OK}" \
  --argjson odoo_fallback_ok "${FALLBACK_OK}" \
  --argjson odoo_restore_ok "${RESTORE_OK}" \
  --argjson mesh_nodes_defined "${MESH_DEFINED}" \
  --argjson mesh_nodes_enabled "${MESH_ENABLED}" \
  --argjson capability_score "${CAP_SCORE}" \
  '{
    created_at: $created_at,
    decision_snapshot: {
      observability_file: $obs_file,
      closure_file: $closure_file,
      fallback_file: $fallback_file,
      restore_file: $restore_file,
      mesh_file: $mesh_file,
      capability_file: $cap_file,
      observability_flow_ok: $observability_flow_ok,
      odoo_closure_ok: $odoo_closure_ok,
      odoo_fallback_ok: $odoo_fallback_ok,
      odoo_restore_ok: $odoo_restore_ok,
      mesh_nodes_defined: $mesh_nodes_defined,
      mesh_nodes_enabled: $mesh_nodes_enabled,
      capability_score: $capability_score,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 108 — Decision Engine Snapshot

## Snapshot
- observability_flow_ok: ${OBS_OK}
- odoo_closure_ok: ${CLOSURE_OK}
- odoo_fallback_ok: ${FALLBACK_OK}
- odoo_restore_ok: ${RESTORE_OK}
- mesh_nodes_defined: ${MESH_DEFINED}
- mesh_nodes_enabled: ${MESH_ENABLED}
- capability_score: ${CAP_SCORE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase108 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
