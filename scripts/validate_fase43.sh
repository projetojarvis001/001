#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 43 ====="

mkdir -p logs/readiness/expired_exception_approvals

echo
echo "===== PREP ====="
rm -f logs/readiness/exception_approval_20990101-000001.json 2>/dev/null || true
rm -f logs/readiness/exception_approval_20000101-000001.json 2>/dev/null || true
rm -f logs/readiness/expired_exception_approvals/exception_approval_20000101-000001.json 2>/dev/null || true

cat > logs/readiness/exception_approval_20000101-000001.json <<'JSON'
{
  "created_at": "2000-01-01T00:00:00Z",
  "actor": "jarvis001",
  "reason": "approval_expirada_teste",
  "scope": "promotion_override",
  "ttl_minutes": 30,
  "expires_at": "2000-01-01T00:30:00Z",
  "result": {
    "approved": true
  }
}
JSON

cat > logs/readiness/exception_approval_20990101-000001.json <<'JSON'
{
  "created_at": "2099-01-01T00:00:00Z",
  "actor": "jarvis001",
  "reason": "approval_ativa_teste",
  "scope": "promotion_override",
  "ttl_minutes": 30,
  "expires_at": "2099-01-01T00:30:00Z",
  "result": {
    "approved": true
  }
}
JSON

echo
echo "===== RUN CLEANUP ====="
./scripts/exception_approval_cleanup.sh

LATEST="$(ls -1t logs/readiness/exception_cleanup_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem log de cleanup"
  exit 1
fi

echo
echo "===== CHECK JSON ====="
jq -e '.summary.total_found >= 2' "${LATEST}" >/dev/null
jq -e '.summary.expired >= 1' "${LATEST}" >/dev/null
jq -e '.summary.moved_to_archive >= 1' "${LATEST}" >/dev/null
echo "[OK] cleanup json consistente"

echo
echo "===== CHECK FILES ====="
test ! -f logs/readiness/exception_approval_20000101-000001.json
test -f logs/readiness/expired_exception_approvals/exception_approval_20000101-000001.json
test -f logs/readiness/exception_approval_20990101-000001.json
echo "[OK] cleanup moveu expirado e preservou ativo"

echo
echo "===== CHECK APPROVAL VALIDACAO ====="
./scripts/exception_approval_check.sh >/tmp/f43_check.out
LATEST_CHECK="$(ls -1t logs/readiness/exception_check_*.json 2>/dev/null | head -n 1 || true)"
jq -e '.approval.valid == true' "${LATEST_CHECK}" >/dev/null
echo "[OK] approval check continua usando approval valida"

echo
echo "===== REPORT ====="
./scripts/exception_approval_cleanup_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
grep -q 'EXCEPTION CLEANUP' scripts/run_daily_stack_routine.sh
echo "[OK] rotina diaria contem cleanup"

echo
echo "[OK] fase 43 validada"
