#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 109 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase109_mesh_activation_seed.sh
SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_seed_*.json' | sort | tail -n 1)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RENDER INVENTORY ====="
./scripts/phase109_mesh_activation_inventory_render.sh
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_inventory_render_*.json' | sort | tail -n 1)"
echo "INV_FILE=${INV_FILE}"

echo
echo "===== PROBE ====="
./scripts/phase109_mesh_activation_probe.sh
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_probe_*.json' | sort | tail -n 1)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== REMOTE HEALTH ====="
./scripts/phase109_mesh_activation_remote_health.sh
HEALTH_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_remote_health_*.json' | sort | tail -n 1)"
echo "HEALTH_FILE=${HEALTH_FILE}"

echo
echo "===== BUILD ====="
./scripts/phase109_mesh_activation_build.sh
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_build_*.json' | sort | tail -n 1)"
echo "BUILD_FILE=${BUILD_FILE}"

echo
echo "===== EVIDENCE ====="
./scripts/phase109_mesh_activation_evidence.sh
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_evidence_*.json' | sort | tail -n 1)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== PACKET ====="
./scripts/phase109_mesh_activation_packet.sh
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_packet_*.json' | sort | tail -n 1)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.inventory_render.overall_ok == true' "${INV_FILE}" >/dev/null
jq -e '.mesh_activation_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.mesh_activation_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_activation_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] control plane da malha comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/load_mesh_env.sh
bash -n scripts/phase109_mesh_activation_seed.sh
bash -n scripts/phase109_mesh_activation_inventory_render.sh
bash -n scripts/phase109_mesh_activation_probe.sh
bash -n scripts/phase109_mesh_activation_remote_health.sh
bash -n scripts/phase109_mesh_activation_build.sh
bash -n scripts/phase109_mesh_activation_evidence.sh
bash -n scripts/phase109_mesh_activation_packet.sh
bash -n scripts/validate_fase109.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 109 validada"
