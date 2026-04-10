#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 40 ====="

echo
echo "===== PREP RELEASE ====="
LATEST_RELEASE="$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_RELEASE}" ] || [ ! -f "${LATEST_RELEASE}" ]; then
  echo "[ERRO] sem release log para teste"
  exit 1
fi
echo "LATEST_RELEASE=${LATEST_RELEASE}"

echo
echo "===== TESTE AUTO ROLLBACK ====="
ACTOR="jarvis001" REASON="teste_fase40" ./scripts/auto_rollback_after_failed_promotion.sh "${LATEST_RELEASE}"

LATEST_AUTO="$(ls -1t logs/release/auto_rollback_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_AUTO}" ] || [ ! -f "${LATEST_AUTO}" ]; then
  echo "[ERRO] sem auto rollback log"
  exit 1
fi

jq -e '.result.rollback_executed == true' "${LATEST_AUTO}" >/dev/null
jq -e '.result.final_status == "ROLLBACK_EXECUTADO" or .result.final_status == "ROLLBACK_FALHOU"' "${LATEST_AUTO}" >/dev/null
jq -e '.source.release_file != null' "${LATEST_AUTO}" >/dev/null
echo "[OK] auto rollback log consistente"

echo
echo "===== REPORT ====="
./scripts/auto_rollback_report.sh "${LATEST_AUTO}"

echo
echo "===== SANIDADE DO PIPELINE ====="
grep -q 'STEP 7: AUTO ROLLBACK' scripts/promote_release.sh
grep -q 'ROLLBACK_EXECUTADO' scripts/promote_release.sh
grep -q 'ROLLBACK_FALHOU' scripts/promote_release.sh
echo "[OK] pipeline preparado para rollback automatico"

echo
echo "[OK] fase 40 validada"
