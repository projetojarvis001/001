#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 87 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase87_odoo_smoke_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN WEB PROBE ====="
python3 scripts/phase87_odoo_smoke_web_probe.py
WEB_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_web_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "WEB_FILE=${WEB_FILE}"

echo
echo "===== RUN RPC PROBE ====="
python3 scripts/phase87_odoo_smoke_rpc_probe.py
RPC_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_rpc_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "RPC_FILE=${RPC_FILE}"

echo
echo "===== RUN INFRA PROBE ====="
./scripts/phase87_odoo_smoke_infra_probe.sh
INFRA_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_infra_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "INFRA_FILE=${INFRA_FILE}"

echo
echo "===== RUN ROLLBACK READINESS ====="
./scripts/phase87_odoo_rollback_readiness.sh
ROLLBACK_FILE="$(ls -1t logs/executive/phase87_odoo_rollback_readiness_*.json 2>/dev/null | head -n 1 || true)"
echo "ROLLBACK_FILE=${ROLLBACK_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase87_odoo_smoke_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase87_odoo_smoke_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.web_probe.http_ok == true' "${WEB_FILE}" >/dev/null
jq -e '.web_probe.login_page_ok == true' "${WEB_FILE}" >/dev/null
jq -e '.rpc_probe.xmlrpc_common_ok == true' "${RPC_FILE}" >/dev/null
jq -e '.rpc_probe.auth_ok == true' "${RPC_FILE}" >/dev/null
jq -e '.infra_probe.has_nginx_8069 == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.has_odoo_8070 == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_probe.public_has_nginx == true' "${INFRA_FILE}" >/dev/null
jq -e '.rollback_readiness.rollback_ready == true' "${ROLLBACK_FILE}" >/dev/null
jq -e '.smoke_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] smoke operacional e rollback readiness do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase87_odoo_smoke_seed.sh
python3 -m py_compile scripts/phase87_odoo_smoke_web_probe.py
python3 -m py_compile scripts/phase87_odoo_smoke_rpc_probe.py
bash -n scripts/phase87_odoo_smoke_infra_probe.sh
bash -n scripts/phase87_odoo_rollback_readiness.sh
bash -n scripts/phase87_odoo_smoke_evidence.sh
bash -n scripts/phase87_odoo_smoke_packet.sh
bash -n scripts/validate_fase87.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 87 validada"
