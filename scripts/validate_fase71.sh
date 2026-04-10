#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 71 ====="

echo
echo "===== BUILD SEMANTIC CASES ====="
./scripts/phase71_vision_semantic_cases.sh
CASES_FILE="$(ls -1t logs/executive/phase71_vision_semantic_cases_*.json 2>/dev/null | head -n 1 || true)"
echo "CASES_FILE=${CASES_FILE}"

echo
echo "===== RUN SEMANTIC RUNNER ====="
python3 scripts/phase71_vision_semantic_runner.py

echo
echo "===== BUILD SEMANTIC SCORE ====="
./scripts/phase71_vision_semantic_score.sh
SCORE_FILE="$(ls -1t logs/executive/phase71_vision_semantic_score_*.json 2>/dev/null | head -n 1 || true)"
echo "SCORE_FILE=${SCORE_FILE}"

echo
echo "===== BUILD SEMANTIC PACKET ====="
./scripts/phase71_vision_semantic_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase71_vision_semantic_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.suite.case_count >= 5' "${CASES_FILE}" >/dev/null
jq -e '.semantic_validation.total_cases >= 5' "${SCORE_FILE}" >/dev/null
jq -e '.semantic_validation.matches >= 4' "${SCORE_FILE}" >/dev/null
jq -e '.summary.negation_fixed == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] endurecimento semantico do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase71_vision_semantic_cases.sh
python3 -m py_compile scripts/phase71_vision_semantic_runner.py
bash -n scripts/phase71_vision_semantic_score.sh
bash -n scripts/phase71_vision_semantic_packet.sh
bash -n scripts/validate_fase71.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 71 validada"
