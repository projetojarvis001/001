#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 89 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase89_odoo_drill_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase89_odoo_drill_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN RESTORE DRILL ====="
./scripts/phase89_odoo_restore_drill.sh
RESTORE_FILE="$(ls -1t logs/executive/phase89_odoo_restore_drill_*.json 2>/dev/null | head -n 1 || true)"
echo "RESTORE_FILE=${RESTORE_FILE}"

echo
echo "===== RUN AUTH PROBE ====="
python3 scripts/phase89_odoo_drill_auth_probe.py
AUTH_FILE="$(ls -1t logs/executive/phase89_odoo_drill_auth_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "AUTH_FILE=${AUTH_FILE}"

echo
echo "===== RUN CLEANUP ====="
./scripts/phase89_odoo_drill_cleanup.sh
CLEANUP_FILE="$(ls -1t logs/executive/phase89_odoo_drill_cleanup_*.json 2>/dev/null | head -n 1 || true)"
echo "CLEANUP_FILE=${CLEANUP_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase89_odoo_drill_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase89_odoo_drill_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase89_odoo_drill_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase89_odoo_drill_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.restore_drill.drill_db_ready == true' "${RESTORE_FILE}" >/dev/null
jq -e '.drill_auth_probe.xmlrpc_common_ok == true' "${AUTH_FILE}" >/dev/null
jq -e '.drill_auth_probe.auth_ok == true' "${AUTH_FILE}" >/dev/null
jq -e '.drill_cleanup.db_removed == true' "${CLEANUP_FILE}" >/dev/null
jq -e '.drill_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.dr_ready == true' "${PACKET_FILE}" >/dev/null
echo "[OK] disaster recovery drill do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase89_odoo_drill_seed.sh
bash -n scripts/phase89_odoo_restore_drill.sh
python3 -m py_compile scripts/phase89_odoo_drill_auth_probe.py
bash -n scripts/phase89_odoo_drill_cleanup.sh
bash -n scripts/phase89_odoo_drill_evidence.sh
bash -n scripts/phase89_odoo_drill_packet.sh
bash -n scripts/validate_fase89.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 89 validada"
