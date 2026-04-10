#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 76 ====="

echo
echo "===== RESET BENCHMARK AREA ====="
find runtime/vision/benchmark/out -maxdepth 1 -type f -name 'benchmark_result_*.json' -delete 2>/dev/null || true
echo "[OK] area benchmark limpa"

echo
echo "===== BUILD BENCHMARK SEED ====="
./scripts/phase76_vision_benchmark_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase76_vision_benchmark_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN BENCHMARK ====="
python3 scripts/phase76_vision_benchmark_runner.py

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase76_vision_benchmark_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase76_vision_benchmark_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase76_vision_benchmark_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase76_vision_benchmark_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.benchmark_flow.benchmark_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.benchmark_live == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.winner_route != ""' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] benchmark operacional do vision comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase76_vision_benchmark_seed.sh
python3 -m py_compile scripts/phase76_vision_benchmark_runner.py
bash -n scripts/phase76_vision_benchmark_evidence.sh
bash -n scripts/phase76_vision_benchmark_packet.sh
bash -n scripts/validate_fase76.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 76 validada"
