#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 75 ====="

echo
echo "===== RESET FALLBACK AREA ====="
find runtime/vision/fallback/out -maxdepth 1 -type f -name 'fallback_result_*.json' -delete 2>/dev/null || true
rm -f runtime/vision/fallback/state/fallback_processed.txt
echo "[OK] area fallback limpa"

echo
echo "===== BUILD FALLBACK SEED ====="
./scripts/phase75_vision_fallback_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase75_vision_fallback_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN FALLBACK ====="
python3 scripts/phase75_vision_fallback_runner.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase75_vision_fallback_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase75_vision_fallback_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase75_vision_fallback_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase75_vision_fallback_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.fallback_flow.fallback_used == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.fallback_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.fallback_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] fallback operacional do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase75_vision_fallback_seed.sh
python3 -m py_compile scripts/phase75_vision_fallback_runner.py
bash -n scripts/phase75_vision_fallback_evidence.sh
bash -n scripts/phase75_vision_fallback_packet.sh
bash -n scripts/validate_fase75.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 75 validada"
