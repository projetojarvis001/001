#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 61 ====="

echo
echo "===== BUILD CLOSE CURRENT STAGE ====="
./scripts/phase61_close_current_stage.sh
CLOSE_FILE="$(ls -1t logs/executive/phase61_stage_closure_*.json 2>/dev/null | head -n 1 || true)"
echo "CLOSE_FILE=${CLOSE_FILE}"

echo
echo "===== BUILD BENCHMARK REINFORCED ====="
./scripts/phase61_benchmark_reinforced.sh
BENCH_FILE="$(ls -1t logs/executive/phase61_benchmark_reinforced_*.json 2>/dev/null | head -n 1 || true)"
echo "BENCH_FILE=${BENCH_FILE}"

echo
echo "===== BUILD PHASE2 BACKLOG ====="
./scripts/phase61_phase2_backlog.sh
BACKLOG_FILE="$(ls -1t logs/executive/phase61_phase2_backlog_*.json 2>/dev/null | head -n 1 || true)"
echo "BACKLOG_FILE=${BACKLOG_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.governance.closure_ready == true or .governance.closure_ready == false' "${CLOSE_FILE}" >/dev/null
jq -e '.suite_name == "phase61_reinforced_governance_suite"' "${BENCH_FILE}" >/dev/null
jq -e '.phase == "FASE_2_AGENTE_VIVO_E_PROATIVO"' "${BACKLOG_FILE}" >/dev/null
jq -e '.modules | length >= 6' "${BACKLOG_FILE}" >/dev/null
echo "[OK] artefatos base da fase 61 consistentes"

echo
echo "===== CHECK GATE POLICY ====="
jq -e '.gate_policy.benchmark_required == true' "${BENCH_FILE}" >/dev/null
jq -e '.gate_policy.smoke_required == true' "${BENCH_FILE}" >/dev/null
echo "[OK] gate policy definida"

echo
echo "===== CHECK BACKLOG ====="
jq -e '.modules[] | select(.module == "devops_agent")' "${BACKLOG_FILE}" >/dev/null
jq -e '.modules[] | select(.module == "vision_listener")' "${BACKLOG_FILE}" >/dev/null
jq -e '.modules[] | select(.module == "vision_recruiter")' "${BACKLOG_FILE}" >/dev/null
jq -e '.modules[] | select(.module == "telegram_governance")' "${BACKLOG_FILE}" >/dev/null
echo "[OK] backlog tecnico contem modulos criticos"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase61_close_current_stage.sh
bash -n scripts/phase61_benchmark_reinforced.sh
bash -n scripts/phase61_phase2_backlog.sh
bash -n scripts/validate_fase61.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 61 validada"
