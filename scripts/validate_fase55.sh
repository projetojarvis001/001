#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 55 ====="

echo
echo "===== BUILD RELIABILITY ====="
./scripts/release_reliability_score.sh

LATEST="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem reliability"
  exit 1
fi

echo "RELIABILITY_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.scoring.final_score >= 0 and .scoring.final_score <= 100' "${LATEST}" >/dev/null
jq -e '.scoring.grade != null' "${LATEST}" >/dev/null
jq -e '.scoring.status != null' "${LATEST}" >/dev/null
jq -e '.context.rollback_status == "NOT_RUN"' "${LATEST}" >/dev/null
jq -e '.context.post_status == "PASS"' "${LATEST}" >/dev/null
echo "[OK] reliability consistente"

echo
echo "===== REPORT ====="
./scripts/release_reliability_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/release_reliability_score.sh
bash -n scripts/release_reliability_report.sh
bash -n scripts/validate_fase55.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 55 validada"
