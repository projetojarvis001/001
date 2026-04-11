#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 116 ====="

./scripts/phase116_mesh_dispatcher_seed.sh
./scripts/phase116_mesh_dispatcher_manifest.sh
./scripts/phase116_mesh_dispatcher_apply.sh
./scripts/phase116_mesh_dispatcher_probe.sh
./scripts/phase116_mesh_dispatcher_build.sh
./scripts/phase116_mesh_dispatcher_evidence.sh
./scripts/phase116_mesh_dispatcher_packet.sh

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_evidence_*.json' | sort | tail -n 1)"
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase116_mesh_dispatcher_packet_*.json' | sort | tail -n 1)"

echo
echo "===== CHECK JSON ====="
jq -e '.mesh_dispatcher_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.mesh_dispatcher_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.mesh_dispatcher_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_dispatcher_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 116 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
