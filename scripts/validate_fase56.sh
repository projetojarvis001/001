#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 56 ====="

echo
echo "===== BUILD PACKET ====="
./scripts/daily_executive_packet.sh

LATEST="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${LATEST}" ] || [ ! -f "${LATEST}" ]; then
  echo "[ERRO] sem daily executive packet"
  exit 1
fi

echo "PACKET_FILE=${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.executive_snapshot != null' "${LATEST}" >/dev/null
jq -e '.operational_discipline.score >= 0 and .operational_discipline.score <= 100' "${LATEST}" >/dev/null
jq -e '.daily_changes.total_events >= 0' "${LATEST}" >/dev/null
jq -e '.latest_release.reliability_score >= 0 and .latest_release.reliability_score <= 100' "${LATEST}" >/dev/null
jq -e '.decision.executive_signal == "NORMAL" or .decision.executive_signal == "CONTROLADO" or .decision.executive_signal == "ATENCAO" or .decision.executive_signal == "CRITICO"' "${LATEST}" >/dev/null
jq -e '.decision.operator_note != null' "${LATEST}" >/dev/null
echo "[OK] packet consistente"

echo
echo "===== CHECK CORRELATION ====="
jq -e '.executive_snapshot.go_live_status == "LIBERAR_COM_RISCO"' "${LATEST}" >/dev/null
jq -e '.latest_release.post_deploy_status == "PASS"' "${LATEST}" >/dev/null
jq -e '.latest_release.rollback_status == "NOT_RUN"' "${LATEST}" >/dev/null
echo "[OK] packet respeita estado atual da release"

echo
echo "===== REPORT ====="
./scripts/daily_executive_packet_report.sh "${LATEST}"

echo
echo "===== SANIDADE ====="
bash -n scripts/daily_executive_packet.sh
bash -n scripts/daily_executive_packet_report.sh
bash -n scripts/validate_fase56.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 56 validada"
