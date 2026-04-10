#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 69 ====="

echo
echo "===== BUILD VISION INVENTORY ====="
./scripts/phase69_vision_inventory.sh
INVENTORY_FILE="$(ls -1t logs/executive/phase69_vision_inventory_*.json 2>/dev/null | head -n 1 || true)"
echo "INVENTORY_FILE=${INVENTORY_FILE}"

echo
echo "===== BUILD VISION READINESS ====="
./scripts/phase69_vision_readiness.sh
READINESS_FILE="$(ls -1t logs/executive/phase69_vision_readiness_*.json 2>/dev/null | head -n 1 || true)"
echo "READINESS_FILE=${READINESS_FILE}"

echo
echo "===== BUILD VISION SCORE GAP ====="
./scripts/phase69_vision_score_gap.sh
SCORE_FILE="$(ls -1t logs/executive/phase69_vision_score_gap_*.json 2>/dev/null | head -n 1 || true)"
echo "SCORE_FILE=${SCORE_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.inventory.script_count >= 0' "${INVENTORY_FILE}" >/dev/null
jq -e '.readiness.readiness_score >= 0 and .readiness.readiness_score <= 100' "${READINESS_FILE}" >/dev/null
jq -e '.vision.base_score >= 0 and .vision.base_score <= 10' "${SCORE_FILE}" >/dev/null
jq -e '.immediate_gaps | length >= 3' "${SCORE_FILE}" >/dev/null
echo "[OK] inventario, readiness e score gap consistentes"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase69_vision_inventory.sh
bash -n scripts/phase69_vision_readiness.sh
bash -n scripts/phase69_vision_score_gap.sh
bash -n scripts/validate_fase69.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 69 validada"
