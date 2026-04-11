#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase104_mesh_inventory_evidence_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_evidence_${TS}.md"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_seed_*.json' | sort | tail -n 1)"
LOCAL_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_local_snapshot_*.json' | sort | tail -n 1)"
REACH_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_reachability_probe_*.json' | sort | tail -n 1)"
CONS_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_consolidation_*.json' | sort | tail -n 1)"

LOCAL_OK=false
REACH_OK=false
CONS_OK=false

jq -e '.local_snapshot.overall_ok == true' "${LOCAL_FILE}" >/dev/null && LOCAL_OK=true || true
jq -e '.reachability_probe.overall_ok == true' "${REACH_FILE}" >/dev/null && REACH_OK=true || true
jq -e '.mesh_inventory.overall_ok == true' "${CONS_FILE}" >/dev/null && CONS_OK=true || true

FLOW_OK=false
if [ "${LOCAL_OK}" = "true" ] && [ "${REACH_OK}" = "true" ] && [ "${CONS_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg local_file "${LOCAL_FILE}" \
  --arg reach_file "${REACH_FILE}" \
  --arg consolidation_file "${CONS_FILE}" \
  --argjson local_ok "${LOCAL_OK}" \
  --argjson reach_ok "${REACH_OK}" \
  --argjson consolidation_ok "${CONS_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_inventory_flow: {
      seed_file: $seed_file,
      local_file: $local_file,
      reach_file: $reach_file,
      consolidation_file: $consolidation_file,
      local_ok: $local_ok,
      reach_ok: $reach_ok,
      consolidation_ok: $consolidation_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 104 — Mesh Inventory Evidence

## Flow
- local_ok: ${LOCAL_OK}
- reach_ok: ${REACH_OK}
- consolidation_ok: ${CONS_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
