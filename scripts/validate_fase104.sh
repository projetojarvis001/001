#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 104 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase104_mesh_inventory_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== LOCAL SNAPSHOT ====="
./scripts/phase104_mesh_inventory_local_snapshot.sh
LOCAL_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_local_snapshot_*.json' | sort | tail -n 1)"
echo "LOCAL_FILE=${LOCAL_FILE}"

echo
echo "===== REACHABILITY PROBE ====="
./scripts/phase104_mesh_inventory_reachability_probe.sh
REACH_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_reachability_probe_*.json' | sort | tail -n 1)"
echo "REACH_FILE=${REACH_FILE}"

echo
echo "===== CONSOLIDATION ====="
./scripts/phase104_mesh_inventory_consolidation.sh
CONS_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_consolidation_*.json' | sort | tail -n 1)"
echo "CONS_FILE=${CONS_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase104_mesh_inventory_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase104_mesh_inventory_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.local_snapshot.overall_ok == true' "${LOCAL_FILE}" >/dev/null
jq -e '.reachability_probe.overall_ok == true' "${REACH_FILE}" >/dev/null
jq -e '.mesh_inventory.overall_ok == true' "${CONS_FILE}" >/dev/null
jq -e '.mesh_inventory_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] inventario vivo da malha comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase104_mesh_inventory_seed.sh
bash -n scripts/phase104_mesh_inventory_local_snapshot.sh
bash -n scripts/phase104_mesh_inventory_reachability_probe.sh
bash -n scripts/phase104_mesh_inventory_consolidation.sh
bash -n scripts/phase104_mesh_inventory_evidence.sh
bash -n scripts/phase104_mesh_inventory_packet.sh
bash -n scripts/validate_fase104.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 104 validada"
