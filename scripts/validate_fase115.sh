#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 115 ====="

./scripts/phase115_mesh_registry_seed.sh
./scripts/phase115_mesh_registry_apply.sh
./scripts/phase115_mesh_registry_probe.sh
./scripts/phase115_mesh_registry_build.sh
./scripts/phase115_mesh_registry_evidence.sh
./scripts/phase115_mesh_registry_packet.sh

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_evidence_*.json' | sort | tail -n 1)"
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase115_mesh_registry_packet_*.json' | sort | tail -n 1)"

echo
echo "===== CHECK JSON ====="
jq -e '.mesh_registry_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.mesh_registry_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.mesh_registry_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_registry_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 115 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
