#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 90B ====="

echo
echo "===== RUN FIXED INFRA PROBE ====="
./scripts/phase90_odoo_monitoring_infra_probe.sh
INFRA_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_infra_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "INFRA_FILE=${INFRA_FILE}"

echo
echo "===== BUILD STATUS ====="
./scripts/phase90_odoo_monitoring_status.sh
STATUS_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_status_*.json 2>/dev/null | head -n 1 || true)"
echo "STATUS_FILE=${STATUS_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase90_odoo_monitoring_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.infra_probe.odoo_state == "active"' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.nginx_state == "active"' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.pg_state == "active"' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.odoo_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.nginx_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.pg_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.has_nginx_8069 == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.has_odoo_8070 == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.has_pg_local == true' "${INFRA_FILE}" >/dev/null
jq -e '.monitoring_status.status == "GREEN"' "${STATUS_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fase 90B saneou o monitoring do odoo"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase90_odoo_monitoring_infra_probe.sh
bash -n scripts/phase90_odoo_monitoring_status.sh
bash -n scripts/phase90_odoo_monitoring_packet.sh
bash -n scripts/validate_fase90b.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 90B validada"
