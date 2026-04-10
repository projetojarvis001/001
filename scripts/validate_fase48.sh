#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 48 ====="

echo
echo "===== BUILD SCORE ====="
./scripts/operational_score_daily.sh

LATEST_SCORE="$(ls -1t logs/executive/operational_score_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_SCORE}" ] || [ ! -f "${LATEST_SCORE}" ]; then
  echo "[ERRO] score operacional nao encontrado"
  exit 1
fi

echo "SCORE_FILE=${LATEST_SCORE}"

echo
echo "===== CHECK JSON ====="
jq -e '.scoring.final_score >= 0 and .scoring.final_score <= 100' "${LATEST_SCORE}" >/dev/null
jq -e '.scoring.grade != null' "${LATEST_SCORE}" >/dev/null
jq -e '.scoring.status != null' "${LATEST_SCORE}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST_SCORE}" >/dev/null
echo "[OK] score consistente"

echo
echo "===== CHECK REPORT ====="
./scripts/operational_score_report.sh "${LATEST_SCORE}"

echo
echo "===== SANIDADE ====="
bash -n scripts/operational_score_daily.sh
bash -n scripts/operational_score_report.sh
bash -n scripts/validate_fase48.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 48 validada"
