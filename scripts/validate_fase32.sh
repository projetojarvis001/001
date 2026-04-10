#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 32 ====="

METRICS_BEFORE="/tmp/fase32_stack_metrics_before.json"
HISTORY_BEFORE="/tmp/fase32_stack_history_before.json"

cp logs/state/stack_metrics.json "${METRICS_BEFORE}"
cp logs/history/stack_daily_history.json "${HISTORY_BEFORE}"

echo
echo "===== READINESS SAFE ====="
./scripts/readiness_gate_safe.sh

LATEST_SAFE=$(ls -1t logs/readiness/readiness_safe_*.json 2>/dev/null | head -n 1 || true)

if [ -z "${LATEST_SAFE}" ] || [ ! -f "${LATEST_SAFE}" ]; then
  echo "[ERRO] readiness safe nao encontrado"
  exit 1
fi

echo "[OK] readiness safe selecionado: ${LATEST_SAFE}"

echo
echo "===== CHECK JSON ====="
jq -e '.mode == "SAFE_NO_CHAOS"' "${LATEST_SAFE}" >/dev/null
jq -e '.readiness != null' "${LATEST_SAFE}" >/dev/null
jq -e '.executive_recommendation != null' "${LATEST_SAFE}" >/dev/null
jq -e '.score != null' "${LATEST_SAFE}" >/dev/null
jq -e '.checks.stack_ok != null' "${LATEST_SAFE}" >/dev/null
jq -e '.artifacts.latest_postgres_backup != null' "${LATEST_SAFE}" >/dev/null
echo "[OK] readiness safe consistente"

echo
echo "===== REPORT ====="
./scripts/readiness_report_safe.sh "${LATEST_SAFE}"

echo
echo "===== DASHBOARD EXECUTIVO ====="
./scripts/build_executive_ops_dashboard.sh

test -f logs/executive/executive_ops_dashboard.json
jq -e '.executive.readiness != null' logs/executive/executive_ops_dashboard.json >/dev/null
jq -e '.decision.go_live_status != null' logs/executive/executive_ops_dashboard.json >/dev/null
echo "[OK] dashboard executivo consistente"

echo
echo "===== CHECK SEM CONTAMINAR METRICAS ====="

BEFORE_DATE=$(jq -r '.date' "${METRICS_BEFORE}")
BEFORE_DOWN=$(jq -r '.down_count' "${METRICS_BEFORE}")
BEFORE_TOTAL=$(jq -r '.total_downtime_seconds' "${METRICS_BEFORE}")
BEFORE_LAST=$(jq -r '.last_downtime_seconds' "${METRICS_BEFORE}")

AFTER_DATE=$(jq -r '.date' logs/state/stack_metrics.json)
AFTER_DOWN=$(jq -r '.down_count' logs/state/stack_metrics.json)
AFTER_TOTAL=$(jq -r '.total_downtime_seconds' logs/state/stack_metrics.json)
AFTER_LAST=$(jq -r '.last_downtime_seconds' logs/state/stack_metrics.json)

echo "BEFORE_DATE=${BEFORE_DATE}"
echo "AFTER_DATE=${AFTER_DATE}"
echo "BEFORE_DOWN=${BEFORE_DOWN}"
echo "AFTER_DOWN=${AFTER_DOWN}"
echo "BEFORE_TOTAL=${BEFORE_TOTAL}"
echo "AFTER_TOTAL=${AFTER_TOTAL}"
echo "BEFORE_LAST=${BEFORE_LAST}"
echo "AFTER_LAST=${AFTER_LAST}"

if [ "${BEFORE_DATE}" != "${AFTER_DATE}" ]; then
  echo "[ERRO] validate_fase32 alterou a data das metricas"
  exit 1
fi

if [ "${BEFORE_DOWN}" != "${AFTER_DOWN}" ]; then
  echo "[ERRO] validate_fase32 contaminou down_count"
  exit 1
fi

if [ "${BEFORE_TOTAL}" != "${AFTER_TOTAL}" ]; then
  echo "[ERRO] validate_fase32 contaminou total_downtime_seconds"
  exit 1
fi

if [ "${BEFORE_LAST}" != "${AFTER_LAST}" ]; then
  echo "[ERRO] validate_fase32 contaminou last_downtime_seconds"
  exit 1
fi

cmp -s "${HISTORY_BEFORE}" logs/history/stack_daily_history.json
echo "[OK] validate_fase32 nao contaminou historico"

echo
echo "===== REGRA FINAL ====="
jq -e '.readiness == "READY" or .readiness == "BLOCKED"' "${LATEST_SAFE}" >/dev/null
echo "[OK] gate safe respondeu com estado valido"

echo
echo "[OK] fase 32 validada"
