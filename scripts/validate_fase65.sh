#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 65 ====="

echo
echo "===== BUILD PUSH AUDIT ====="
./scripts/phase65_push_audit.sh
AUDIT_FILE="$(ls -1t logs/executive/phase65_push_audit_*.json 2>/dev/null | head -n 1 || true)"
echo "AUDIT_FILE=${AUDIT_FILE}"

echo
echo "===== BUILD PUSH EXECUTE ====="
./scripts/phase65_push_execute.sh
PUSH_FILE="$(ls -1t logs/executive/phase65_push_execute_*.json 2>/dev/null | head -n 1 || true)"
echo "PUSH_FILE=${PUSH_FILE}"

echo
echo "===== BUILD POST PUSH VERIFY ====="
./scripts/phase65_post_push_verify.sh
VERIFY_FILE="$(ls -1t logs/executive/phase65_post_push_verify_*.json 2>/dev/null | head -n 1 || true)"
echo "VERIFY_FILE=${VERIFY_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.repo.head_short != ""' "${AUDIT_FILE}" >/dev/null
jq -e '.governance.push_executed == true' "${PUSH_FILE}" >/dev/null
jq -e '.verify.remote_match == true' "${VERIFY_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PUSH_FILE}" >/dev/null
echo "[OK] push controlado consistente"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase65_push_audit.sh
bash -n scripts/phase65_push_execute.sh
bash -n scripts/phase65_post_push_verify.sh
bash -n scripts/validate_fase65.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 65 validada"
