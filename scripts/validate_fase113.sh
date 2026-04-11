#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

echo "===== VALIDATE FASE 113 ====="

./scripts/phase113_mesh_credentials_seed.sh
./scripts/phase113_mesh_credentials_snapshot.sh
./scripts/phase113_mesh_connectivity_probe.sh
./scripts/phase113_mesh_connectivity_build.sh
./scripts/phase113_mesh_connectivity_evidence.sh
./scripts/phase113_mesh_connectivity_packet.sh

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_credentials_snapshot_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_evidence_*.json' | sort | tail -n 1)"
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase113_mesh_connectivity_packet_*.json' | sort | tail -n 1)"

jq -e '.credentials_snapshot.env_exists == true' "${SNAP_FILE}" >/dev/null
jq -e '.connectivity_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_connectivity_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 113 validada"
echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
