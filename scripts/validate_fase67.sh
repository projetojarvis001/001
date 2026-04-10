#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 67 ====="

echo
echo "===== CHECK INTEGRATION IN ROUTINE ====="
grep -q './scripts/devops_agent_status.sh' scripts/run_daily_stack_routine.sh
grep -q './scripts/phase66_devops_packet.sh' scripts/run_daily_stack_routine.sh
echo "[OK] rotina diaria contem os blocos devops"

echo
echo "===== BUILD DEVOPS STATUS ====="
./scripts/devops_agent_status.sh
STATUS_FILE="$(ls -1t logs/executive/devops_agent_status_*.json 2>/dev/null | head -n 1 || true)"
echo "STATUS_FILE=${STATUS_FILE}"

echo
echo "===== BUILD DEVOPS PACKET ====="
./scripts/phase66_devops_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase66_devops_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.decision.agent_ready == true' "${STATUS_FILE}" >/dev/null
jq -e '.summary.agent_ready == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.remote_match == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] artefatos devops consistentes"

echo
echo "===== REPORT ====="
./scripts/phase67_devops_daily_integration_report.sh

echo
echo "===== SANIDADE ====="
bash -n scripts/devops_agent_status.sh
bash -n scripts/devops_agent_status_report.sh
bash -n scripts/phase66_devops_packet.sh
bash -n scripts/phase67_devops_daily_integration_report.sh
bash -n scripts/validate_fase67.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 67 validada"
