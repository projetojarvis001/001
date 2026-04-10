#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 50 ====="

echo
echo "===== PREP HISTORY ====="
./scripts/operational_score_daily.sh >/tmp/f50_score.out
./scripts/operational_score_history_update.sh >/tmp/f50_hist.out

echo
echo "===== BUILD TREND ====="
./scripts/operational_score_trend.sh

LATEST_TREND="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_TREND}" ] || [ ! -f "${LATEST_TREND}" ]; then
  echo "[ERRO] trend nao encontrado"
  exit 1
fi

echo "TREND_FILE=${LATEST_TREND}"

echo
echo "===== CHECK JSON ====="
jq -e '.summary.total_days >= 1' "${LATEST_TREND}" >/dev/null
jq -e '.summary.average_score_all >= 0 and .summary.average_score_all <= 100' "${LATEST_TREND}" >/dev/null
jq -e '.summary.average_score_recent >= 0 and .summary.average_score_recent <= 100' "${LATEST_TREND}" >/dev/null
jq -e '.summary.trend == "UP" or .summary.trend == "STABLE" or .summary.trend == "DOWN"' "${LATEST_TREND}" >/dev/null
jq -e '.summary.executive_band != null' "${LATEST_TREND}" >/dev/null
jq -e '.highlights.latest_day.reference_day != null' "${LATEST_TREND}" >/dev/null
echo "[OK] trend consistente"

echo
echo "===== REPORT ====="
./scripts/operational_score_trend_report.sh "${LATEST_TREND}"

echo
echo "===== SANIDADE ====="
bash -n scripts/operational_score_trend.sh
bash -n scripts/operational_score_trend_report.sh
bash -n scripts/validate_fase50.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 50 validada"
