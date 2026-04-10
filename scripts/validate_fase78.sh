#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 78 ====="

echo
echo "===== RESET MEMORY AREA ====="
find runtime/vision/memory/out -maxdepth 1 -type f -name 'memory_result_*.json' -delete 2>/dev/null || true
rm -f runtime/vision/memory/state/memory_processed.txt
echo "[OK] area memory limpa"

echo
echo "===== BUILD MEMORY SEED ====="
./scripts/phase78_vision_memory_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase78_vision_memory_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN MEMORY RUNNER ====="
python3 scripts/phase78_vision_memory_runner.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase78_vision_memory_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase78_vision_memory_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase78_vision_memory_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase78_vision_memory_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.memory_flow.memory_events_used >= 2' "${EVIDENCE_FILE}" >/dev/null
jq -e '.memory_flow.memory_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.memory_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] memoria contextual do vision comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase78_vision_memory_seed.sh
python3 -m py_compile scripts/phase78_vision_memory_runner.py
bash -n scripts/phase78_vision_memory_evidence.sh
bash -n scripts/phase78_vision_memory_packet.sh
bash -n scripts/validate_fase78.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 78 validada"
