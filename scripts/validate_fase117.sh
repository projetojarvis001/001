#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 117 ====="

./scripts/phase117_mesh_scheduler_seed.sh
./scripts/phase117_mesh_scheduler_queue.sh
./scripts/phase117_mesh_scheduler_run.sh
./scripts/phase117_mesh_scheduler_build.sh
./scripts/phase117_mesh_scheduler_evidence.sh
./scripts/phase117_mesh_scheduler_packet.sh

RUN_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_run_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_evidence_*.json' | sort | tail -n 1)"
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase117_mesh_scheduler_packet_*.json' | sort | tail -n 1)"

echo
echo "===== CHECK JSON ====="
jq -e '.mesh_scheduler_run.overall_ok == true' "${RUN_FILE}" >/dev/null
jq -e '.mesh_scheduler_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_scheduler_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 117 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
