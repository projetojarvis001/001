#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 51 ====="

echo
echo "===== PREP ====="
./scripts/operational_score_daily.sh >/tmp/f51_score.out
./scripts/operational_score_history_update.sh >/tmp/f51_hist.out
./scripts/operational_score_trend.sh >/tmp/f51_trend.out

echo
echo "===== BUILD DASHBOARD ====="
./scripts/build_executive_ops_dashboard.sh

DASH_FILE="logs/executive/executive_ops_dashboard.json"
if [ ! -f "${DASH_FILE}" ]; then
  echo "[ERRO] dashboard nao encontrado"
  exit 1
fi

echo
echo "===== CHECK JSON ====="
jq -e '.operational_discipline != null' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.score >= 0 and .operational_discipline.score <= 100' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.grade != null' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.status != null' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.trend == "UP" or .operational_discipline.trend == "STABLE" or .operational_discipline.trend == "DOWN" or .operational_discipline.trend == "UNKNOWN"' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.executive_band != null' "${DASH_FILE}" >/dev/null
jq -e '.operational_discipline.operator_note != null' "${DASH_FILE}" >/dev/null
jq -e '.artifacts.score_file != null' "${DASH_FILE}" >/dev/null
jq -e '.artifacts.trend_file != null' "${DASH_FILE}" >/dev/null
echo "[OK] dashboard enriquecido consistente"

echo
echo "===== VIEW ====="
cat "${DASH_FILE}" | jq '.operational_discipline, .artifacts'

echo
echo "===== SANIDADE ====="
bash -n scripts/build_executive_ops_dashboard.sh
bash -n scripts/validate_fase51.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 51 validada"
