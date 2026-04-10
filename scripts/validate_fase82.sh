#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 82 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase82_odoo_hardening_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase82_odoo_hardening_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN REMOTE HARDENING PROBE ====="
./scripts/phase82_odoo_remote_hardening_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase82_odoo_remote_hardening_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD RISK ====="
./scripts/phase82_odoo_risk_assessment.sh
RISK_FILE="$(ls -1t logs/executive/phase82_odoo_risk_assessment_*.json 2>/dev/null | head -n 1 || true)"
echo "RISK_FILE=${RISK_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase82_odoo_hardening_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase82_odoo_hardening_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.hardening_probe.raw_file != ""' "${PROBE_FILE}" >/dev/null
jq -e '.risk.risk_level != ""' "${RISK_FILE}" >/dev/null
jq -e '.summary.risk_level != ""' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] superficie de risco do odoo comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase82_odoo_hardening_seed.sh
bash -n scripts/phase82_odoo_remote_hardening_probe.sh
bash -n scripts/phase82_odoo_risk_assessment.sh
bash -n scripts/phase82_odoo_hardening_packet.sh
bash -n scripts/validate_fase82.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 82 validada"
