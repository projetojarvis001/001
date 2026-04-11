#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 97 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase97_odoo_watchdog_drift_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== BUILD BASELINE ====="
./scripts/phase97_odoo_watchdog_drift_baseline.sh
BASELINE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_baseline_*.json 2>/dev/null | head -n 1 || true)"
echo "BASELINE_FILE=${BASELINE_FILE}"

echo
echo "===== RUN PROBE ====="
./scripts/phase97_odoo_watchdog_drift_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase97_odoo_watchdog_drift_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase97_odoo_watchdog_drift_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase97_odoo_watchdog_drift_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.drift_baseline.cron_watchdog == true' "${BASELINE_FILE}" >/dev/null
jq -e '.drift_baseline.cron_retention == true' "${BASELINE_FILE}" >/dev/null
jq -e '.drift_baseline.stamp_present == true' "${BASELINE_FILE}" >/dev/null
jq -e '.drift_probe.send_match == true' "${PROBE_FILE}" >/dev/null
jq -e '.drift_probe.env_match == true' "${PROBE_FILE}" >/dev/null
jq -e '.drift_probe.retention_match == true' "${PROBE_FILE}" >/dev/null
jq -e '.drift_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.drift_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] drift control remoto do watchdog do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase97_odoo_watchdog_drift_seed.sh
bash -n scripts/phase97_odoo_watchdog_drift_baseline.sh
bash -n scripts/phase97_odoo_watchdog_drift_probe.sh
bash -n scripts/phase97_odoo_watchdog_drift_evidence.sh
bash -n scripts/phase97_odoo_watchdog_drift_packet.sh
bash -n scripts/validate_fase97.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 97 validada"
