#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 98 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase98_odoo_watchdog_restore_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== BUILD MANIFEST ====="
./scripts/phase98_odoo_watchdog_restore_manifest.sh
MANIFEST_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"
echo "MANIFEST_FILE=${MANIFEST_FILE}"

echo
echo "===== RUN RESTORE DRILL ====="
./scripts/phase98_odoo_watchdog_restore_drill.sh
DRILL_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_drill_*.json 2>/dev/null | head -n 1 || true)"
echo "DRILL_FILE=${DRILL_FILE}"

echo
echo "===== RUN PROBE ====="
./scripts/phase98_odoo_watchdog_restore_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase98_odoo_watchdog_restore_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase98_odoo_watchdog_restore_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase98_odoo_watchdog_restore_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.restore_manifest.send_ok == true and .restore_manifest.env_ok == true and .restore_manifest.retention_ok == true and .restore_manifest.cron_ok == true' "${MANIFEST_FILE}" >/dev/null
jq -e '.restore_drill.overall_ok == true' "${DRILL_FILE}" >/dev/null
jq -e '.restore_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.restore_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] restore operacional do watchdog remoto do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase98_odoo_watchdog_restore_seed.sh
bash -n scripts/phase98_odoo_watchdog_restore_manifest.sh
bash -n scripts/phase98_odoo_watchdog_restore_drill.sh
bash -n scripts/phase98_odoo_watchdog_restore_probe.sh
bash -n scripts/phase98_odoo_watchdog_restore_evidence.sh
bash -n scripts/phase98_odoo_watchdog_restore_packet.sh
bash -n scripts/validate_fase98.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 98 validada"
