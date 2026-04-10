#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 42 ====="

echo
echo "===== TESTE BLOQUEIO SEM APROVACAO ====="
rm -f logs/readiness/exception_approval_*.json
rm -f logs/readiness/exception_check_*.json

set +e
ALLOW_OUTSIDE_WINDOW=1 \
ALLOW_RISKY_RELEASE=1 \
ACTOR="jarvis001" \
REASON="teste_sem_aprovacao" \
./scripts/promote_release.sh >/tmp/f42_no_approval.out 2>&1
RC=$?
set -e

if [ "${RC}" -eq 0 ]; then
  echo "[ERRO] promotion passou sem aprovacao excepcional"
  cat /tmp/f42_no_approval.out
  exit 1
fi
echo "[OK] promotion bloqueada sem aprovacao"

echo
echo "===== TESTE APROVACAO EXCEPCIONAL ====="
ACTOR="jarvis001" REASON="teste_fase42" TTL_MINUTES=30 SCOPE="promotion_override" ./scripts/exception_approval_grant.sh
./scripts/exception_approval_check.sh

LATEST_CHECK="$(ls -1t logs/readiness/exception_check_*.json 2>/dev/null | head -n 1 || true)"
jq -e '.approval.valid == true' "${LATEST_CHECK}" >/dev/null
echo "[OK] aprovacao excepcional valida"

echo
echo "===== TESTE PROMOCAO COM APROVACAO ====="
ALLOW_OUTSIDE_WINDOW=1 \
ALLOW_RISKY_RELEASE=1 \
ACTOR="jarvis001" \
REASON="teste_fase42" \
./scripts/promote_release.sh || true

LATEST_PROMO="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
jq -e '.exception_approval.required == true' "${LATEST_PROMO}" >/dev/null
jq -e '.exception_approval.valid == true' "${LATEST_PROMO}" >/dev/null
echo "[OK] promotion reconheceu aprovacao excepcional"

echo
echo "===== REPORT ====="
./scripts/exception_approval_report.sh "${LATEST_CHECK}"

echo
echo "===== SANIDADE ====="
grep -q 'STEP 3B: EXCEPTION APPROVAL' scripts/promote_release.sh
echo "[OK] pipeline contem approval gate"

echo
echo "[OK] fase 42 validada"
