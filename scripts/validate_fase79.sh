#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 79 ====="

echo
echo "===== BUILD OBSERVABILITY ====="
./scripts/phase79_vision_observability_build.sh
OBS_FILE="$(ls -1t logs/executive/phase79_vision_observability_*.json 2>/dev/null | head -n 1 || true)"
echo "OBS_FILE=${OBS_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase79_vision_observability_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase79_vision_observability_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.observability.live_capabilities.routing_live == true' "${OBS_FILE}" >/dev/null
jq -e '.observability.live_capabilities.memory_live == true' "${OBS_FILE}" >/dev/null
jq -e '.observability.live_capabilities.benchmark_live == true' "${OBS_FILE}" >/dev/null
jq -e '.observability.live_capabilities.queue_live == true' "${OBS_FILE}" >/dev/null
jq -e '.observability.observability_ok == true' "${OBS_FILE}" >/dev/null
jq -e '.summary.observability_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] observabilidade real do vision comprovada"

echo
echo "===== REPORT ====="
./scripts/phase79_vision_exec_report.sh "${OBS_FILE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase79_vision_observability_build.sh
bash -n scripts/phase79_vision_exec_report.sh
bash -n scripts/phase79_vision_observability_packet.sh
bash -n scripts/validate_fase79.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 79 validada"
