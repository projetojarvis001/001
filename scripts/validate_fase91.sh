#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 91 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase91_odoo_watchdog_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN WATCHDOG ====="
python3 scripts/phase91_odoo_watchdog_run.py
WATCHDOG_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_run_*.json 2>/dev/null | head -n 1 || true)"
echo "WATCHDOG_FILE=${WATCHDOG_FILE}"

echo
echo "===== RUN INFRA ====="
./scripts/phase91_odoo_watchdog_infra.sh
INFRA_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_infra_*.json 2>/dev/null | head -n 1 || true)"
echo "INFRA_FILE=${INFRA_FILE}"

echo
echo "===== BUILD ALERT ARTIFACT ====="
./scripts/phase91_odoo_alert_artifact.sh
ALERT_FILE="$(ls -1t logs/executive/phase91_odoo_alert_artifact_*.json 2>/dev/null | head -n 1 || true)"
echo "ALERT_FILE=${ALERT_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase91_odoo_watchdog_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase91_odoo_watchdog_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.watchdog_run.web_ok == true' "${WATCHDOG_FILE}" >/dev/null
jq -e '.watchdog_run.auth_ok == true' "${WATCHDOG_FILE}" >/dev/null
jq -e '.infra_watchdog.odoo_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_watchdog.nginx_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.infra_watchdog.pg_active == true' "${INFRA_FILE}" >/dev/null
jq -e '.alert_artifact.channel_ready == true' "${ALERT_FILE}" >/dev/null
jq -e '.watchdog_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] watchdog e artifact readiness do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase91_odoo_watchdog_seed.sh
python3 -m py_compile scripts/phase91_odoo_watchdog_run.py
bash -n scripts/phase91_odoo_watchdog_infra.sh
bash -n scripts/phase91_odoo_alert_artifact.sh
bash -n scripts/phase91_odoo_watchdog_evidence.sh
bash -n scripts/phase91_odoo_watchdog_packet.sh
bash -n scripts/validate_fase91.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 91 validada"
