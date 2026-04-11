#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 99 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase99_odoo_alert_fallback_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== APPLY FALLBACK ====="
./scripts/phase99_odoo_alert_fallback_apply.sh
APPLY_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_apply_*.json 2>/dev/null | head -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== RUN DRILL ====="
./scripts/phase99_odoo_alert_fallback_drill.sh
DRILL_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_drill_*.json 2>/dev/null | head -n 1 || true)"
echo "DRILL_FILE=${DRILL_FILE}"

echo
echo "===== RUN PROBE ====="
./scripts/phase99_odoo_alert_fallback_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase99_odoo_alert_fallback_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase99_odoo_alert_fallback_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase99_odoo_alert_fallback_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.fallback_apply.script_ok == true and .fallback_apply.backup_ok == true and .fallback_apply.fallback_ok == true' "${APPLY_FILE}" >/dev/null
jq -e '.fallback_drill.overall_ok == true' "${DRILL_FILE}" >/dev/null
jq -e '.fallback_probe.overall_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.fallback_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fallback operacional do alerta do watchdog do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase99_odoo_alert_fallback_seed.sh
bash -n scripts/phase99_odoo_alert_fallback_apply.sh
bash -n scripts/phase99_odoo_alert_fallback_drill.sh
bash -n scripts/phase99_odoo_alert_fallback_probe.sh
bash -n scripts/phase99_odoo_alert_fallback_evidence.sh
bash -n scripts/phase99_odoo_alert_fallback_packet.sh
bash -n scripts/validate_fase99.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 99 validada"
