#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 66 ====="

echo
echo "===== BUILD DEVOPS AGENT STATUS ====="
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
jq -e '.git.branch != ""' "${STATUS_FILE}" >/dev/null
jq -e '.runtime.docker_daemon_ok == true' "${STATUS_FILE}" >/dev/null
jq -e '.decision.agent_ready == true' "${STATUS_FILE}" >/dev/null
jq -e '.summary.phase == "FASE_66_DEVOPS_STATUS"' "${PACKET_FILE}" >/dev/null
jq -e '.summary.remote_match == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fase 66 consistente"

echo
echo "===== CHECK GOVERNANCE ====="
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
jq -e '.governance.production_changed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] governanca preservada"

echo
echo "===== REPORT ====="
./scripts/devops_agent_status_report.sh "${STATUS_FILE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/devops_agent_status.sh
bash -n scripts/devops_agent_status_report.sh
bash -n scripts/phase66_devops_packet.sh
bash -n scripts/validate_fase66.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 66 validada"
