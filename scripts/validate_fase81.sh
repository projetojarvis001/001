#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 81 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase81_odoo_inventory_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase81_odoo_inventory_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN REMOTE PROBE ====="
./scripts/phase81_odoo_remote_probe.sh
REMOTE_FILE="$(ls -1t logs/executive/phase81_odoo_remote_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "REMOTE_FILE=${REMOTE_FILE}"

echo
echo "===== RUN APP PROBE ====="
python3 scripts/phase81_odoo_app_probe.py
APP_FILE="$(ls -1t logs/executive/phase81_odoo_app_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "APP_FILE=${APP_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase81_odoo_inventory_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase81_odoo_inventory_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase81_odoo_inventory_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase81_odoo_inventory_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.inventory_flow.http_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.inventory_flow.auth_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.inventory_flow.readiness_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.readiness_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] inventario e readiness do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase81_odoo_inventory_seed.sh
bash -n scripts/phase81_odoo_remote_probe.sh
python3 -m py_compile scripts/phase81_odoo_app_probe.py
bash -n scripts/phase81_odoo_inventory_evidence.sh
bash -n scripts/phase81_odoo_inventory_packet.sh
bash -n scripts/validate_fase81.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 81 validada"
