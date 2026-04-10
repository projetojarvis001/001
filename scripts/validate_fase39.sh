#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 39 ====="

echo
echo "===== TESTE POST DEPLOY VERIFY ====="
./scripts/post_deploy_verify.sh

LATEST_VERIFY=$(ls -1t logs/release/post_deploy_verify_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_VERIFY}" ] || [ ! -f "${LATEST_VERIFY}" ]; then
  echo "[ERRO] sem post deploy verify"
  exit 1
fi

jq -e '.result.status == "PASS" or .result.status == "FAIL"' "${LATEST_VERIFY}" >/dev/null
jq -e '.execution.attempts != null' "${LATEST_VERIFY}" >/dev/null
jq -e '.stack_health != null' "${LATEST_VERIFY}" >/dev/null
echo "[OK] post deploy verify consistente"

echo
echo "===== REPORT ====="
./scripts/post_deploy_report.sh "${LATEST_VERIFY}"

echo
echo "===== TESTE PROMOTION COM POST DEPLOY ====="
ALLOW_OUTSIDE_WINDOW=1 \
ALLOW_RISKY_RELEASE=1 \
ACTOR="jarvis001" \
REASON="teste_fase39" \
./scripts/promote_release.sh || true

LATEST_PROMO=$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_PROMO}" ] || [ ! -f "${LATEST_PROMO}" ]; then
  echo "[ERRO] sem promotion log"
  exit 1
fi

jq -e '.post_deploy.status != null' "${LATEST_PROMO}" >/dev/null
jq -e '.sources.post_deploy_file != null' "${LATEST_PROMO}" >/dev/null
jq -e '.result.final_status != null' "${LATEST_PROMO}" >/dev/null
echo "[OK] promotion integrado com post deploy"

echo
echo "===== RESULT ====="
cat "${LATEST_PROMO}" | jq '.post_deploy, .result'

echo
echo "[OK] fase 39 validada"
