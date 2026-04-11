#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 106 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase106_topology_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== SNAPSHOT ====="
./scripts/phase106_topology_snapshot.sh
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_snapshot_*.json' | sort | tail -n 1)"
echo "SNAP_FILE=${SNAP_FILE}"

echo
echo "===== BUILD TOPOLOGY ====="
./scripts/phase106_topology_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== BUILD MERMAID ====="
./scripts/phase106_topology_mermaid.sh
MERMAID_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_mermaid_*.json' | sort | tail -n 1)"
echo "MERMAID_FILE=${MERMAID_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase106_topology_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase106_topology_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase106_topology_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.topology_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null
jq -e '.topology_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.topology_mermaid.overall_ok == true' "${MERMAID_FILE}" >/dev/null
jq -e '.topology_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.links_total > 0' topology/system_topology.json >/dev/null
echo "[OK] topologia e comunicacoes comprovadas"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase106_topology_seed.sh
bash -n scripts/phase106_topology_snapshot.sh
bash -n scripts/phase106_topology_build.sh
bash -n scripts/phase106_topology_mermaid.sh
bash -n scripts/phase106_topology_evidence.sh
bash -n scripts/phase106_topology_packet.sh
bash -n scripts/validate_fase106.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 106 validada"
