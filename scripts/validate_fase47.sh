#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 47 ====="

LEDGER_FILE="logs/ops/ops_event_ledger.jsonl"

if [ ! -f "${LEDGER_FILE}" ]; then
  echo "[ERRO] ledger operacional inexistente"
  exit 1
fi

echo
echo "===== BUILD SUMMARY ====="
./scripts/daily_change_summary.sh

LATEST_SUMMARY="$(ls -1t logs/executive/daily_change_summary_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_SUMMARY}" ] || [ ! -f "${LATEST_SUMMARY}" ]; then
  echo "[ERRO] resumo diario nao encontrado"
  exit 1
fi

echo "SUMMARY_FILE=${LATEST_SUMMARY}"

echo
echo "===== CHECK JSON ====="
jq -e '.summary.total_events >= 0' "${LATEST_SUMMARY}" >/dev/null
jq -e '.summary.promotion_count >= 0' "${LATEST_SUMMARY}" >/dev/null
jq -e '.releases.risk_releases >= 0' "${LATEST_SUMMARY}" >/dev/null
jq -e '.decision.executive_signal != null' "${LATEST_SUMMARY}" >/dev/null
jq -e '.events != null' "${LATEST_SUMMARY}" >/dev/null
echo "[OK] resumo diario consistente"

echo
echo "===== CHECK REPORT ====="
./scripts/daily_change_summary_report.sh "${LATEST_SUMMARY}"

echo
echo "===== CHECK EVENT INTEGRITY ====="
jq -e '.events | type == "array"' "${LATEST_SUMMARY}" >/dev/null
echo "[OK] eventos incorporados ao resumo"

echo
echo "===== SANIDADE ====="
bash -n scripts/daily_change_summary.sh
bash -n scripts/daily_change_summary_report.sh
bash -n scripts/validate_fase47.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 47 validada"
