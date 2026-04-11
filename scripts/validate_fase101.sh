#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 101 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase101_odoo_watchdog_drift_rebaseline_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== BUILD CAPTURE ====="
./scripts/phase101_odoo_watchdog_drift_rebaseline_capture.sh
CAPTURE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_capture_*.json 2>/dev/null | head -n 1 || true)"
echo "CAPTURE_FILE=${CAPTURE_FILE}"

echo
echo "===== RUN PROBE ====="
./scripts/phase101_odoo_watchdog_drift_rebaseline_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase101_odoo_watchdog_drift_rebaseline_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase101_odoo_watchdog_drift_rebaseline_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.drift_rebaseline.overall_ok == true' "${CAPTURE_FILE}" >/dev/null
jq -e '.drift_rebaseline_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.drift_rebaseline_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] recalibracao de drift do watchdog remoto do odoo comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase101_odoo_watchdog_drift_rebaseline_seed.sh
bash -n scripts/phase101_odoo_watchdog_drift_rebaseline_capture.sh
bash -n scripts/phase101_odoo_watchdog_drift_rebaseline_probe.sh
bash -n scripts/phase101_odoo_watchdog_drift_rebaseline_evidence.sh
bash -n scripts/phase101_odoo_watchdog_drift_rebaseline_packet.sh
bash -n scripts/validate_fase101.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 101 validada"
