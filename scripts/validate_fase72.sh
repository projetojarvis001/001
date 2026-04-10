#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 72 ====="

echo
echo "===== BUILD LISTENER SEED ====="
./scripts/phase72_vision_listener_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase72_vision_listener_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN LISTENER ====="
python3 scripts/phase72_vision_listener.py

echo
echo "===== BUILD LISTENER EVIDENCE ====="
./scripts/phase72_vision_listener_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase72_vision_listener_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD LISTENER PACKET ====="
./scripts/phase72_vision_listener_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase72_vision_listener_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.listener_flow.auto_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.listener_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] listener minimo do vision comprovado"

echo
echo "===== SANIDADE ====="
python3 -m py_compile scripts/phase72_vision_listener.py
bash -n scripts/phase72_vision_listener_seed.sh
bash -n scripts/phase72_vision_listener_evidence.sh
bash -n scripts/phase72_vision_listener_packet.sh
bash -n scripts/validate_fase72.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 72 validada"
