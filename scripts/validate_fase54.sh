#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 54 ====="

echo
echo "===== BUILD TIMELINE ====="
./scripts/release_timeline_build.sh

LATEST="$(ls -1t logs/release/release_timeline_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem timeline"
  exit 1
fi

echo "TIMELINE_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.timeline | type == "array"' "${LATEST}" >/dev/null
jq -e '.timeline | length >= 8' "${LATEST}" >/dev/null
jq -e '.decision.final_status != null' "${LATEST}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST}" >/dev/null
jq -e '.timeline[] | select(.step == "promotion")' "${LATEST}" >/dev/null
jq -e '.timeline[] | select(.step == "semaphore")' "${LATEST}" >/dev/null
echo "[OK] timeline consistente"

echo
echo "===== CHECK CORRELATION ====="
jq -e '.timeline[] | select(.step == "post_deploy") | .status == "PASS"' "${LATEST}" >/dev/null
jq -e '.timeline[] | select(.step == "rollback") | .status == "NOT_RUN"' "${LATEST}" >/dev/null
echo "[OK] timeline respeita promocao saudavel atual"

echo
echo "===== REPORT ====="
./scripts/release_timeline_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/release_timeline_build.sh
bash -n scripts/release_timeline_report.sh
bash -n scripts/validate_fase54.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 54 validada"
