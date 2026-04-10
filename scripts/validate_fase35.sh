#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 35 ====="

echo
echo "===== PREP RISK ====="
./scripts/operational_risk_gate.sh >/tmp/f35_risk.out

LATEST_RISK=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_RISK}" ] || [ ! -f "${LATEST_RISK}" ]; then
  echo "[ERRO] sem operational_risk"
  exit 1
fi

STATUS=$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${LATEST_RISK}")
echo "GO_LIVE_STATUS=${STATUS}"

echo
echo "===== TESTE BLOQUEIO PADRAO ====="
set +e
./scripts/deploy_controlled.sh >/tmp/f35_block.out 2>&1
RC_BLOCK=$?
set -e

if [ "${STATUS}" = "LIBERAR" ]; then
  echo "[INFO] gate liberado sem risco; bloqueio padrao nao se aplica"
else
  if [ "${RC_BLOCK}" -eq 0 ]; then
    echo "[ERRO] deploy passou sem override quando nao devia"
    cat /tmp/f35_block.out
    exit 1
  fi
  echo "[OK] deploy bloqueado sem override"
fi

echo
echo "===== TESTE OVERRIDE ====="
ALLOW_RISKY_RELEASE=1 ACTOR="jarvis001" REASON="teste_fase35" ./scripts/deploy_controlled.sh

LATEST_RELEASE=$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_RELEASE}" ] || [ ! -f "${LATEST_RELEASE}" ]; then
  echo "[ERRO] sem release log"
  exit 1
fi

jq -e '.result.deploy_authorized == true' "${LATEST_RELEASE}" >/dev/null
jq -e '.result.mode == "OVERRIDE_EXPLICITO" or .result.mode == "NORMAL"' "${LATEST_RELEASE}" >/dev/null
jq -e '.decision.go_live_status != null' "${LATEST_RELEASE}" >/dev/null
jq -e '.decision.risk_level != null' "${LATEST_RELEASE}" >/dev/null
echo "[OK] log de release consistente"

echo
echo "===== REPORT ====="
./scripts/release_audit_report.sh "${LATEST_RELEASE}"

echo
echo "[OK] fase 35 validada"
