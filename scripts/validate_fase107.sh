#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 107 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase107_capability_matrix_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== SNAPSHOT ====="
./scripts/phase107_capability_matrix_snapshot.sh
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_snapshot_*.json' | sort | tail -n 1)"
echo "SNAP_FILE=${SNAP_FILE}"

echo
echo "===== BUILD MATRIX ====="
./scripts/phase107_capability_matrix_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== BUILD REPORT ====="
./scripts/phase107_capability_matrix_report.sh
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_report_*.json' | sort | tail -n 1)"
echo "REPORT_FILE=${REPORT_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase107_capability_matrix_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase107_capability_matrix_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase107_capability_matrix_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.capability_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null
jq -e '.capability_matrix_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.capability_report.overall_ok == true' "${REPORT_FILE}" >/dev/null
jq -e '.capability_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.capability_matrix.overall_score >= 0' capability/system_capability_matrix.json >/dev/null
echo "[OK] matriz de capacidades comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase107_capability_matrix_seed.sh
bash -n scripts/phase107_capability_matrix_snapshot.sh
bash -n scripts/phase107_capability_matrix_build.sh
bash -n scripts/phase107_capability_matrix_report.sh
bash -n scripts/phase107_capability_matrix_evidence.sh
bash -n scripts/phase107_capability_matrix_packet.sh
bash -n scripts/validate_fase107.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 107 validada"
