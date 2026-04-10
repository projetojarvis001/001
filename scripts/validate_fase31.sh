#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 31 ====="

echo
echo "===== BUILD DASHBOARD ====="
./scripts/build_executive_ops_dashboard.sh

LATEST="logs/executive/executive_ops_dashboard.json"

if [ ! -f "${LATEST}" ]; then
  echo "[ERRO] dashboard executivo nao encontrado"
  exit 1
fi

echo
echo "===== CHECK JSON ====="
jq -e '.executive.readiness != null' "${LATEST}" >/dev/null
jq -e '.executive.score != null' "${LATEST}" >/dev/null
jq -e '.executive.slo_today_percent != null' "${LATEST}" >/dev/null
jq -e '.operations.autoheal_last_result != null' "${LATEST}" >/dev/null
jq -e '.artifacts.latest_postgres_backup != null' "${LATEST}" >/dev/null
jq -e '.decision.go_live_status != null' "${LATEST}" >/dev/null
echo "[OK] dashboard executivo consistente"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase30.sh

echo
echo "[OK] fase 31 validada"
