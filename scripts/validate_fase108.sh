#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 108 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase108_decision_engine_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== SNAPSHOT ====="
./scripts/phase108_decision_engine_snapshot.sh
SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_snapshot_*.json' | sort | tail -n 1)"
echo "SNAP_FILE=${SNAP_FILE}"

echo
echo "===== BUILD ENGINE ====="
./scripts/phase108_decision_engine_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== BUILD REPORT ====="
./scripts/phase108_decision_engine_report.sh
REPORT_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_report_*.json' | sort | tail -n 1)"
echo "REPORT_FILE=${REPORT_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase108_decision_engine_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase108_decision_engine_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.decision_snapshot.overall_ok == true' "${SNAP_FILE}" >/dev/null
jq -e '.decision_engine_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.decision_engine_report.overall_ok == true' "${REPORT_FILE}" >/dev/null
jq -e '.decision_engine_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] motor de decisao operacional comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase108_decision_engine_seed.sh
bash -n scripts/phase108_decision_engine_snapshot.sh
bash -n scripts/phase108_decision_engine_build.sh
bash -n scripts/phase108_decision_engine_report.sh
bash -n scripts/phase108_decision_engine_evidence.sh
bash -n scripts/phase108_decision_engine_packet.sh
bash -n scripts/validate_fase108.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 108 validada"
