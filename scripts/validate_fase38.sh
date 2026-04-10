#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 38 ====="

echo
echo "===== PREP ====="
./scripts/readiness_gate_strict.sh >/dev/null
./scripts/operational_risk_gate.sh >/dev/null

echo
echo "===== TESTE BLOQUEIO POR JANELA ====="
if WINDOW_START="00:00" WINDOW_END="00:01" ./scripts/promote_release.sh >/tmp/f38_block.out 2>&1; then
  echo "[ERRO] promotion nao deveria passar fora da janela"
  cat /tmp/f38_block.out
  exit 1
fi

LATEST_PROMO=$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_PROMO}" ] || [ ! -f "${LATEST_PROMO}" ]; then
  echo "[ERRO] sem promotion log de bloqueio"
  exit 1
fi

jq -e '.result.promotion_authorized == false' "${LATEST_PROMO}" >/dev/null
jq -e '.result.final_status == "BLOQUEAR"' "${LATEST_PROMO}" >/dev/null
echo "[OK] bloqueio por janela validado"

echo
echo "===== TESTE PROMOCAO COM OVERRIDE ====="
WINDOW_START="00:00" WINDOW_END="00:01" \
ALLOW_OUTSIDE_WINDOW=1 \
ALLOW_RISKY_RELEASE=1 \
ACTOR="jarvis001" \
REASON="teste_fase38" \
./scripts/promote_release.sh

LATEST_PROMO=$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_PROMO}" ] || [ ! -f "${LATEST_PROMO}" ]; then
  echo "[ERRO] sem promotion log final"
  exit 1
fi

jq -e '.result.promotion_authorized == true' "${LATEST_PROMO}" >/dev/null
jq -e '.result.deploy_executed == true' "${LATEST_PROMO}" >/dev/null
jq -e '.result.mode == "OVERRIDE_EXPLICITO" or .result.mode == "NORMAL"' "${LATEST_PROMO}" >/dev/null
jq -e '.sources.readiness_file != null' "${LATEST_PROMO}" >/dev/null
jq -e '.sources.risk_file != null' "${LATEST_PROMO}" >/dev/null
jq -e '.sources.change_window_file != null' "${LATEST_PROMO}" >/dev/null
jq -e '.sources.deploy_file != null' "${LATEST_PROMO}" >/dev/null
echo "[OK] promotion log consistente"

echo
echo "===== REPORT ====="
./scripts/promotion_report.sh "${LATEST_PROMO}"

echo
echo "[OK] fase 38 validada"
