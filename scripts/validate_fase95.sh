#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 95 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase95_odoo_alert_delivery_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== DEPLOY ALERT DELIVERY ====="
./scripts/phase95_odoo_alert_delivery_deploy.sh
DEPLOY_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_deploy_*.json 2>/dev/null | head -n 1 || true)"
echo "DEPLOY_FILE=${DEPLOY_FILE}"

echo
echo "===== PROBE ALERT DELIVERY ====="
./scripts/phase95_odoo_alert_delivery_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase95_odoo_alert_delivery_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase95_odoo_alert_delivery_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase95_odoo_alert_delivery_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.alert_delivery_deploy.script_ok == true' "${DEPLOY_FILE}" >/dev/null
jq -e '.alert_delivery_deploy.test_ok == true' "${DEPLOY_FILE}" >/dev/null
jq -e '.alert_delivery_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.alert_delivery_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] entrega real de alerta remoto do odoo comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase95_odoo_alert_delivery_seed.sh
bash -n scripts/phase95_odoo_alert_delivery_deploy.sh
bash -n scripts/phase95_odoo_alert_delivery_probe.sh
bash -n scripts/phase95_odoo_alert_delivery_evidence.sh
bash -n scripts/phase95_odoo_alert_delivery_packet.sh
bash -n scripts/validate_fase95.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 95 validada"
