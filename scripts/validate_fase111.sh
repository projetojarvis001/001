#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 111 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase111_mesh_runtime_real_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_seed_*.json' | sort | tail -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== INVENTORY ====="
./scripts/phase111_mesh_runtime_real_inventory.sh
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_inventory_*.json' | sort | tail -n 1 || true)"
echo "INV_FILE=${INV_FILE}"

echo
echo "===== APPLY ====="
./scripts/phase111_mesh_runtime_real_apply.sh
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_apply_*.json' | sort | tail -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== PROBE ====="
./scripts/phase111_mesh_runtime_real_probe.sh
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_probe_*.json' | sort | tail -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD ====="
./scripts/phase111_mesh_runtime_real_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_build_*.json' | sort | tail -n 1 || true)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase111_mesh_runtime_real_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_evidence_*.json' | sort | tail -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase111_mesh_runtime_real_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase111_mesh_runtime_real_packet_*.json' | sort | tail -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.runtime_inventory.overall_ok == true' "${INV_FILE}" >/dev/null
jq -e '.mesh_runtime_real_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.mesh_runtime_real_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_runtime_real_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 111 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
