#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 92 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase92_odoo_scheduler_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN WATCHDOG RUNNER ====="
./scripts/phase92_odoo_watchdog_runner.sh
RUNNER_FILE="$(ls -1t logs/executive/phase92_odoo_watchdog_runner_*.json 2>/dev/null | head -n 1 || true)"
echo "RUNNER_FILE=${RUNNER_FILE}"

echo
echo "===== BUILD SCHEDULER ARTIFACT ====="
./scripts/phase92_odoo_scheduler_artifact.sh
ARTIFACT_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_artifact_*.json 2>/dev/null | head -n 1 || true)"
echo "ARTIFACT_FILE=${ARTIFACT_FILE}"

echo
echo "===== BUILD TRACE ====="
./scripts/phase92_odoo_scheduler_trace.sh
TRACE_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_trace_*.json 2>/dev/null | head -n 1 || true)"
echo "TRACE_FILE=${TRACE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase92_odoo_scheduler_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase92_odoo_scheduler_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase92_odoo_scheduler_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.runner.flow_ok == true' "${RUNNER_FILE}" >/dev/null
jq -e '.scheduler_artifact.scheduler_ready == true' "${ARTIFACT_FILE}" >/dev/null
jq -e '.scheduler_trace.trace_ok == true' "${TRACE_FILE}" >/dev/null
jq -e '.scheduler_flow.evidence_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] scheduler readiness do watchdog do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase92_odoo_scheduler_seed.sh
bash -n scripts/phase92_odoo_watchdog_runner.sh
bash -n scripts/phase92_odoo_scheduler_artifact.sh
bash -n scripts/phase92_odoo_scheduler_trace.sh
bash -n scripts/phase92_odoo_scheduler_evidence.sh
bash -n scripts/phase92_odoo_scheduler_packet.sh
bash -n scripts/validate_fase92.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 92 validada"
