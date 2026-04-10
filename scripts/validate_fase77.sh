#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 77 ====="

echo
echo "===== RESET POLICY AREA ====="
find runtime/vision/policy/out -maxdepth 1 -type f -name 'policy_result_*.json' -delete 2>/dev/null || true
rm -f runtime/vision/policy/state/policy_processed.txt
echo "[OK] area policy limpa"

echo
echo "===== BUILD POLICY SEED ====="
./scripts/phase77_vision_policy_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase77_vision_policy_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN POLICY ROUTER ====="
python3 scripts/phase77_vision_policy_router.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase77_vision_policy_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase77_vision_policy_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase77_vision_policy_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase77_vision_policy_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.policy_flow.routing_policy_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.routing_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] roteamento inteligente do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase77_vision_policy_seed.sh
python3 -m py_compile scripts/phase77_vision_policy_router.py
bash -n scripts/phase77_vision_policy_evidence.sh
bash -n scripts/phase77_vision_policy_packet.sh
bash -n scripts/validate_fase77.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 77 validada"
