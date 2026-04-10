#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 80 ====="

echo
echo "===== RESET REGISTRY AREA ====="
find runtime/vision/registry/out -maxdepth 1 -type f -name 'registry_result_*.json' -delete 2>/dev/null || true
rm -f runtime/vision/registry/state/registry_processed.txt
echo "[OK] area registry limpa"

echo
echo "===== BUILD REGISTRY SEED ====="
./scripts/phase80_vision_registry_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase80_vision_registry_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN RECRUITER ====="
python3 scripts/phase80_vision_recruiter_runner.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase80_vision_registry_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase80_vision_registry_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase80_vision_registry_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase80_vision_registry_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.registry_flow.rank_count >= 3' "${EVIDENCE_FILE}" >/dev/null
jq -e '.registry_flow.registry_flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.registry_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.promoted_route != ""' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] recruiter registry do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase80_vision_registry_seed.sh
python3 -m py_compile scripts/phase80_vision_recruiter_runner.py
bash -n scripts/phase80_vision_registry_evidence.sh
bash -n scripts/phase80_vision_registry_packet.sh
bash -n scripts/validate_fase80.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 80 validada"
