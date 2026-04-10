#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 90 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase90_odoo_monitoring_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN WEB PROBE ====="
python3 scripts/phase90_odoo_monitoring_web_probe.py
WEB_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_web_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "WEB_FILE=${WEB_FILE}"

echo
echo "===== RUN RPC PROBE ====="
python3 scripts/phase90_odoo_monitoring_rpc_probe.py
RPC_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_rpc_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "RPC_FILE=${RPC_FILE}"

echo
echo "===== RUN INFRA PROBE ====="
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
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.web_probe.http_ok == true' "${WEB_FILE}" >/dev/null
jq -e '.web_probe.login_page_ok == true' "${WEB_FILE}" >/dev/null
jq -e '.rpc_probe.xmlrpc_common_ok == true' "${RPC_FILE}" >/dev/null
jq -e '.rpc_probe.auth_ok == true' "${RPC_FILE}" >/dev/null
jq -e '.infra_probe.odoo_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.nginx_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.pg_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.monitoring_status.status == "GREEN"' "${STATUS_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] monitoring e alert readiness do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase90_odoo_monitoring_seed.sh
python3 -m py_compile scripts/phase90_odoo_monitoring_web_probe.py
python3 -m py_compile scripts/phase90_odoo_monitoring_rpc_probe.py
bash -n scripts/phase90_odoo_monitoring_infra_probe.sh
bash -n scripts/phase90_odoo_monitoring_status.sh
bash -n scripts/phase90_odoo_monitoring_packet.sh
bash -n scripts/validate_fase90.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 90 validada"
