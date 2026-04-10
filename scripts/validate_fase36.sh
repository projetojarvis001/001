#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 36 ====="

echo
echo "===== PREP RELEASE ====="
LATEST_RELEASE=$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)

if [ -z "${LATEST_RELEASE}" ] || [ ! -f "${LATEST_RELEASE}" ]; then
  echo "[ERRO] sem release log para rollback"
  exit 1
fi

echo "LATEST_RELEASE=${LATEST_RELEASE}"

echo
echo "===== TESTE ROLLBACK ====="
ACTOR="jarvis001" REASON="teste_fase36" ./scripts/rollback_controlled.sh "${LATEST_RELEASE}"

LATEST_ROLLBACK=$(ls -1t logs/release/rollback_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_ROLLBACK}" ] || [ ! -f "${LATEST_ROLLBACK}" ]; then
  echo "[ERRO] sem rollback log"
  exit 1
fi

jq -e '.result.rollback_authorized == true' "${LATEST_ROLLBACK}" >/dev/null
jq -e '.result.rollback_executed == true' "${LATEST_ROLLBACK}" >/dev/null
jq -e '.source.release_file != null' "${LATEST_ROLLBACK}" >/dev/null
jq -e '.source.go_live_status != null' "${LATEST_ROLLBACK}" >/dev/null
echo "[OK] rollback log consistente"

echo
echo "===== REPORT ====="
./scripts/rollback_audit_report.sh "${LATEST_ROLLBACK}"

echo
echo "[OK] fase 36 validada"
