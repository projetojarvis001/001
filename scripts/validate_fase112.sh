#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 112 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase112_mesh_readiness_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== SNAPSHOT ====="
./scripts/phase112_mesh_readiness_snapshot.sh
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_snapshot_*.json' | sort | tail -n 1)"
echo "SNAP_FILE=${SNAP_FILE}"

echo
echo "===== INVENTORY CHECK ====="
./scripts/phase112_mesh_readiness_inventory_check.sh
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_inventory_check_*.json' | sort | tail -n 1)"
echo "INV_FILE=${INV_FILE}"

echo
echo "===== BUILD ====="
./scripts/phase112_mesh_readiness_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== REPORT ====="
./scripts/phase112_mesh_readiness_report.sh
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_report_*.json' | sort | tail -n 1)"
echo "REPORT_FILE=${REPORT_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase112_mesh_readiness_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase112_mesh_readiness_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.readiness_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null
jq -e '.inventory_check.overall_ok == true' "${INV_FILE}" >/dev/null
jq -e '.readiness_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.readiness_report.overall_ok == true' "${REPORT_FILE}" >/dev/null
jq -e '.mesh_readiness_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fase 112 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
