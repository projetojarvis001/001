#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 45 ====="

echo
echo "===== PREP PROMOTION ====="
ALLOW_OUTSIDE_WINDOW=1 \
ALLOW_RISKY_RELEASE=1 \
ACTOR="jarvis001" \
REASON="teste_fase45" \
./scripts/promote_release.sh || true

LATEST_PROMO="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_PROMO}" ] || [ ! -f "${LATEST_PROMO}" ]; then
  echo "[ERRO] sem promotion log para gerar manifest"
  exit 1
fi
echo "PROMOTION_FILE=${LATEST_PROMO}"

echo
echo "===== BUILD MANIFEST ====="
./scripts/release_manifest_build.sh "${LATEST_PROMO}"

LATEST_MANIFEST="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST_MANIFEST}" ] || [ ! -f "${LATEST_MANIFEST}" ]; then
  echo "[ERRO] sem release manifest"
  exit 1
fi
echo "MANIFEST_FILE=${LATEST_MANIFEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.release_identity.actor != null' "${LATEST_MANIFEST}" >/dev/null
jq -e '.sources.promotion_file != null' "${LATEST_MANIFEST}" >/dev/null
jq -e '.governance.risk_level != null' "${LATEST_MANIFEST}" >/dev/null
jq -e '.execution.final_status != null' "${LATEST_MANIFEST}" >/dev/null
jq -e '.git.commit != null' "${LATEST_MANIFEST}" >/dev/null
jq -e '.observability.stack_ok != null' "${LATEST_MANIFEST}" >/dev/null
echo "[OK] manifest consistente"

echo
echo "===== CHECK SOURCES ====="
PROMOTION_FILE="$(jq -r '.sources.promotion_file // ""' "${LATEST_MANIFEST}")"
READINESS_FILE="$(jq -r '.sources.readiness_file // ""' "${LATEST_MANIFEST}")"
RISK_FILE="$(jq -r '.sources.risk_file // ""' "${LATEST_MANIFEST}")"
WINDOW_FILE="$(jq -r '.sources.change_window_file // ""' "${LATEST_MANIFEST}")"

test -f "${PROMOTION_FILE}"
test -f "${READINESS_FILE}"
test -f "${RISK_FILE}"
test -f "${WINDOW_FILE}"
echo "[OK] fontes criticas existem"

echo
echo "===== CHECK STATUS ====="
jq -e '.execution.final_status == "LIBERAR_COM_RISCO" or .execution.final_status == "LIBERAR" or .execution.final_status == "BLOQUEAR" or .execution.final_status == "FALHA_POS_DEPLOY" or .execution.final_status == "ROLLBACK_EXECUTADO" or .execution.final_status == "ROLLBACK_FALHOU"' "${LATEST_MANIFEST}" >/dev/null
echo "[OK] status final valido"

echo
echo "===== REPORT ====="
./scripts/release_manifest_report.sh "${LATEST_MANIFEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/release_manifest_build.sh
bash -n scripts/release_manifest_report.sh
bash -n scripts/validate_fase45.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 45 validada"
