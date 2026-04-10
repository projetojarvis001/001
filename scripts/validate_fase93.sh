#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 93 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase93_odoo_remote_watchdog_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== DEPLOY REMOTE WATCHDOG ====="
./scripts/phase93_odoo_remote_watchdog_deploy.sh
DEPLOY_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_deploy_*.json 2>/dev/null | head -n 1 || true)"
echo "DEPLOY_FILE=${DEPLOY_FILE}"

echo
echo "===== PROBE REMOTE WATCHDOG ====="
./scripts/phase93_odoo_remote_watchdog_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase93_odoo_remote_watchdog_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase93_odoo_remote_watchdog_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase93_odoo_remote_watchdog_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.remote_watchdog_deploy.cron_ok == true' "${DEPLOY_FILE}" >/dev/null
jq -e '.remote_watchdog_deploy.run_ok == true' "${DEPLOY_FILE}" >/dev/null
jq -e '.remote_watchdog_deploy.stamp_ok == true' "${DEPLOY_FILE}" >/dev/null
jq -e '.remote_watchdog_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.remote_watchdog_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] watchdog remoto do odoo implantado e comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase93_odoo_remote_watchdog_seed.sh
bash -n scripts/phase93_odoo_remote_watchdog_deploy.sh
bash -n scripts/phase93_odoo_remote_watchdog_probe.sh
bash -n scripts/phase93_odoo_remote_watchdog_evidence.sh
bash -n scripts/phase93_odoo_remote_watchdog_packet.sh
bash -n scripts/validate_fase93.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 93 validada"
