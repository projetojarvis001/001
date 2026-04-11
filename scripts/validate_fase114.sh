#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 114 ====="

./scripts/phase114_mesh_http_bootstrap_seed.sh
./scripts/phase114_mesh_http_bootstrap_apply.sh
./scripts/phase114_mesh_http_bootstrap_probe.sh
./scripts/phase114_mesh_http_bootstrap_build.sh
./scripts/phase114_mesh_http_bootstrap_evidence.sh
./scripts/phase114_mesh_http_bootstrap_packet.sh

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_build_*.json' | sort | tail -n 1)"
EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_evidence_*.json' | sort | tail -n 1)"
PACKET_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_packet_*.json' | sort | tail -n 1)"

echo
echo "===== CHECK JSON ====="
jq -e '.mesh_http_bootstrap_apply.overall_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.mesh_http_bootstrap_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.mesh_http_bootstrap_build.overall_ok == true' "${BUILD_FILE}" >/dev/null
jq -e '.mesh_http_bootstrap_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null

echo "[OK] fase 114 validada"

echo
echo "===== STATUS ====="
jq -r '.summary.status' "${PACKET_FILE}"
