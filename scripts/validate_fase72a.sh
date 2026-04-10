#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 72A ====="

echo
echo "===== RESET TEST AREA ====="
rm -f runtime/vision/inbox/task_*.json
rm -f runtime/vision/outbox/result_*.json
rm -f runtime/vision/state/processed_tasks.txt
echo "[OK] area limpa"

echo
echo "===== BUILD SEED ====="
./scripts/phase72_vision_listener_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase72_vision_listener_seed_*.json 2>/dev/null | head -n 1 || true)"
TARGET_TASK_FILE="$(jq -r '.seed.task_file // ""' "${SEED_FILE}")"
echo "SEED_FILE=${SEED_FILE}"
echo "TARGET_TASK_FILE=${TARGET_TASK_FILE}"

echo
echo "===== RUN TARGETED LISTENER ====="
export VISION_TARGET_TASK_FILE="${TARGET_TASK_FILE}"
python3 scripts/phase72_vision_listener.py
unset VISION_TARGET_TASK_FILE

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase72_vision_listener_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase72_vision_listener_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase72_vision_listener_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase72_vision_listener_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.listener_flow.processed_in_ledger == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.listener_flow.auto_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.listener_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] 72A saneou a prova do listener"

echo
echo "===== SANIDADE ====="
python3 -m py_compile scripts/phase72_vision_listener.py
bash -n scripts/phase72_vision_listener_seed.sh
bash -n scripts/phase72_vision_listener_evidence.sh
bash -n scripts/phase72_vision_listener_packet.sh
bash -n scripts/validate_fase72a.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 72A validada"
