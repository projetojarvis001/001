#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 68 ====="

echo
echo "===== BUILD MATRIX ====="
./scripts/phase68_ten_by_ten_matrix.sh
MATRIX_FILE="$(ls -1t logs/executive/phase68_ten_by_ten_matrix_*.json 2>/dev/null | head -n 1 || true)"
echo "MATRIX_FILE=${MATRIX_FILE}"

echo
echo "===== BUILD SCORING ====="
./scripts/phase68_component_scoring.sh
SCORING_FILE="$(ls -1t logs/executive/phase68_component_scoring_*.json 2>/dev/null | head -n 1 || true)"
echo "SCORING_FILE=${SCORING_FILE}"

echo
echo "===== BUILD GAP PLAN ====="
./scripts/phase68_gap_attack_plan.sh
GAP_FILE="$(ls -1t logs/executive/phase68_gap_attack_plan_*.json 2>/dev/null | head -n 1 || true)"
echo "GAP_FILE=${GAP_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.components[] | select(.component == "JARVIS")' "${MATRIX_FILE}" >/dev/null
jq -e '.components[] | select(.component == "VISION")' "${MATRIX_FILE}" >/dev/null
jq -e '.components[] | select(.component == "FRIDAY")' "${MATRIX_FILE}" >/dev/null
jq -e '.components[] | select(.component == "ODOO")' "${MATRIX_FILE}" >/dev/null
jq -e '.components[] | select(.component == "JARVIS" and .current_score >= 0 and .current_score <= 10)' "${SCORING_FILE}" >/dev/null
jq -e '.attack_order[0].component == "VISION"' "${GAP_FILE}" >/dev/null
echo "[OK] matriz, scoring e gap plan consistentes"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase68_ten_by_ten_matrix.sh
bash -n scripts/phase68_component_scoring.sh
bash -n scripts/phase68_gap_attack_plan.sh
bash -n scripts/validate_fase68.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 68 validada"
