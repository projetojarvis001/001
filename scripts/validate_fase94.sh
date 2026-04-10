#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 94 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase94_odoo_watchdog_retention_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== APPLY RETENTION ====="
./scripts/phase94_odoo_watchdog_retention_apply.sh
APPLY_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_apply_*.json 2>/dev/null | head -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== PROBE RETENTION ====="
./scripts/phase94_odoo_watchdog_retention_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase94_odoo_watchdog_retention_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase94_odoo_watchdog_retention_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase94_odoo_watchdog_retention_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.retention_apply.script_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.retention_apply.cron_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.retention_apply.run_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.retention_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.retention_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] retention e housekeeping do watchdog remoto do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase94_odoo_watchdog_retention_seed.sh
bash -n scripts/phase94_odoo_watchdog_retention_apply.sh
bash -n scripts/phase94_odoo_watchdog_retention_probe.sh
bash -n scripts/phase94_odoo_watchdog_retention_evidence.sh
bash -n scripts/phase94_odoo_watchdog_retention_packet.sh
bash -n scripts/validate_fase94.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 94 validada"
