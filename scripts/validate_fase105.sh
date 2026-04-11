#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 105 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase105_executive_dashboard_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== SNAPSHOT ====="
./scripts/phase105_executive_dashboard_snapshot.sh
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_snapshot_*.json' | sort | tail -n 1)"
echo "SNAP_FILE=${SNAP_FILE}"

echo
echo "===== BUILD DASHBOARD ====="
./scripts/phase105_executive_dashboard_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase105_executive_dashboard_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase105_executive_dashboard_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.dashboard_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null
jq -e '.dashboard_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.dashboard_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.executive_status.system_status != ""' dashboard/executive_status_dashboard.json >/dev/null
echo "[OK] dashboard executivo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase105_executive_dashboard_seed.sh
bash -n scripts/phase105_executive_dashboard_snapshot.sh
bash -n scripts/phase105_executive_dashboard_build.sh
bash -n scripts/phase105_executive_dashboard_evidence.sh
bash -n scripts/phase105_executive_dashboard_packet.sh
bash -n scripts/validate_fase105.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 105 validada"
