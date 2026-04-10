#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 44 ====="

mkdir -p logs/readiness

echo
echo "===== PREP ====="
rm -f logs/readiness/exception_approval_20260410-020000.json
rm -f logs/readiness/exception_approval_20260410-020500.json
rm -f logs/readiness/exception_resolve_*.json
rm -f logs/readiness/exception_check_*.json

cat > logs/readiness/exception_approval_20260410-020000.json <<'JSON'
{
  "created_at": "2026-04-10T05:20:00Z",
  "actor": "alice",
  "reason": "approval_antiga",
  "scope": "promotion_override",
  "ttl_minutes": 30,
  "expires_at": "2099-01-01T00:00:00Z",
  "result": {
    "approved": true
  }
}
JSON

cat > logs/readiness/exception_approval_20260410-020500.json <<'JSON'
{
  "created_at": "2026-04-10T05:25:00Z",
  "actor": "alice",
  "reason": "approval_nova",
  "scope": "promotion_override",
  "ttl_minutes": 30,
  "expires_at": "2099-01-01T00:00:00Z",
  "result": {
    "approved": true
  }
}
JSON

echo "[OK] approvals de teste criadas"

echo
echo "===== TESTE RESOLVE MAIS RECENTE ====="
./scripts/exception_approval_resolve.sh promotion_override
LATEST_RESOLVE=$(ls -1t logs/readiness/exception_resolve_*.json | head -n 1)

jq -e '.selected_file | endswith("exception_approval_20260410-020500.json")' "${LATEST_RESOLVE}" >/dev/null
echo "[OK] resolve escolheu approval mais recente"

echo
echo "===== TESTE RESOLVE COM FILTRO DE ATOR ====="
ACTOR_FILTER="alice" ./scripts/exception_approval_resolve.sh promotion_override
LATEST_RESOLVE_ACTOR=$(ls -1t logs/readiness/exception_resolve_*.json | head -n 1)

jq -e '.selected_file | endswith("exception_approval_20260410-020500.json")' "${LATEST_RESOLVE_ACTOR}" >/dev/null
echo "[OK] resolve com actor filter consistente"

echo
echo "===== TESTE CHECK ====="
ACTOR_FILTER="alice" ./scripts/exception_approval_check.sh
LATEST_CHECK=$(ls -1t logs/readiness/exception_check_*.json | head -n 1)

jq -e '.approval.valid == true' "${LATEST_CHECK}" >/dev/null
jq -e '.source.approval_file | endswith("exception_approval_20260410-020500.json")' "${LATEST_CHECK}" >/dev/null
echo "[OK] approval check usa approval correta"

echo
echo "===== TESTE ESCOPO INEXISTENTE ====="
set +e
./scripts/exception_approval_resolve.sh escopo_que_nao_existe >/tmp/f44_resolve_fail.out 2>&1
RC=$?
set -e

if [ "${RC}" -eq 0 ]; then
  echo "[ERRO] resolve deveria falhar para escopo inexistente"
  cat /tmp/f44_resolve_fail.out
  exit 1
fi
echo "[OK] resolve falhou corretamente para escopo inexistente"

echo
echo "===== SANIDADE ====="
bash -n scripts/exception_approval_resolve.sh
bash -n scripts/exception_approval_check.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 44 validada"
