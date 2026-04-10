#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 70 ====="

echo
echo "===== BUILD TASK SEED ====="
./scripts/phase70_vision_task_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase70_vision_task_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN CONTROLLED FLOW ====="
python3 scripts/phase70_vision_runner.py

echo
echo "===== BUILD FLOW EVIDENCE ====="
./scripts/phase70_vision_flow_evidence.sh
FLOW_FILE="$(ls -1t logs/executive/phase70_vision_flow_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "FLOW_FILE=${FLOW_FILE}"

echo
echo "===== BUILD LIVE PACKET ====="
./scripts/phase70_vision_first_live_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase70_vision_first_live_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.task_file != ""' "${SEED_FILE}" >/dev/null
jq -e '.flow.match_ok == true' "${FLOW_FILE}" >/dev/null
jq -e '.flow.status_out == "processed"' "${FLOW_FILE}" >/dev/null
jq -e '.summary.live_flow_proven == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] primeiro fluxo vivo do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase70_vision_task_seed.sh
python3 -m py_compile scripts/phase70_vision_runner.py
bash -n scripts/phase70_vision_flow_evidence.sh
bash -n scripts/phase70_vision_first_live_packet.sh
bash -n scripts/validate_fase70.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 70 validada"
