#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATUS_FILE="$(ls -1t logs/executive/devops_agent_status_*.json 2>/dev/null | head -n 1 || true)"
PACKET_FILE="$(ls -1t logs/executive/phase66_devops_packet_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${STATUS_FILE}" ] || [ ! -f "${STATUS_FILE}" ]; then
  echo "[ERRO] status do devops agent nao encontrado"
  exit 1
fi

if [ -z "${PACKET_FILE}" ] || [ ! -f "${PACKET_FILE}" ]; then
  echo "[ERRO] packet da fase 66 nao encontrado"
  exit 1
fi

echo "===== PHASE 67 DEVOPS DAILY INTEGRATION REPORT ====="
echo "STATUS_FILE=${STATUS_FILE}"
echo "PACKET_FILE=${PACKET_FILE}"
echo

jq -r '
"CREATED_AT=" + (.created_at // ""),
"",
"===== SUMMARY =====",
(.summary | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== DECISION =====",
(.decision | to_entries[] | (.key + "=" + (.value|tostring))),
"",
"===== GOVERNANCE =====",
(.governance | to_entries[] | (.key + "=" + (.value|tostring)))
' "${PACKET_FILE}"

echo
echo "[OK] relatorio da integracao emitido"
