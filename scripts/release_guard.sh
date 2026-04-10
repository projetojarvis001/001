#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

RISK_FILE=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)

if [ -z "${RISK_FILE}" ] || [ ! -f "${RISK_FILE}" ]; then
  echo "[ERRO] sem operational_risk"
  exit 1
fi

GO_LIVE_STATUS=$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")
NOTE=$(jq -r '.decision.operator_note // "Sem nota"' "${RISK_FILE}")

echo "RISK_FILE=${RISK_FILE}"
echo "GO_LIVE_STATUS=${GO_LIVE_STATUS}"
echo "NOTE=${NOTE}"

case "${GO_LIVE_STATUS}" in
  LIBERAR)
    echo "[OK] release liberado"
    exit 0
    ;;
  LIBERAR_COM_RISCO|OPERAR_COM_CAUTELA)
    if [ "${ALLOW_RISKY_RELEASE:-0}" = "1" ]; then
      echo "[WARN] release liberado com risco por override explicito"
      exit 0
    fi
    echo "[ERRO] release bloqueado por risco. Use ALLOW_RISKY_RELEASE=1 se for decisao consciente."
    exit 1
    ;;
  BLOQUEAR|*)
    echo "[ERRO] release bloqueado"
    exit 1
    ;;
esac
