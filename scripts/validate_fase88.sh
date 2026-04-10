#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 88 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase88_odoo_backup_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase88_odoo_backup_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN BACKUP ====="
./scripts/phase88_odoo_backup_run.sh
RUN_FILE="$(ls -1t logs/executive/phase88_odoo_backup_run_*.json 2>/dev/null | head -n 1 || true)"
echo "RUN_FILE=${RUN_FILE}"

echo
echo "===== BUILD RESTORE MANIFEST ====="
./scripts/phase88_odoo_restore_manifest.sh
MANIFEST_FILE="$(ls -1t logs/executive/phase88_odoo_restore_manifest_*.json 2>/dev/null | head -n 1 || true)"
echo "MANIFEST_FILE=${MANIFEST_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase88_odoo_backup_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase88_odoo_backup_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase88_odoo_backup_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase88_odoo_backup_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.backup_run.db_dump_ok == true' "${RUN_FILE}" >/dev/null
jq -e '.backup_run.odoo_conf_ok == true' "${RUN_FILE}" >/dev/null
jq -e '.backup_run.nginx_conf_ok == true' "${RUN_FILE}" >/dev/null
jq -e '.restore_manifest.restore_ready == true' "${MANIFEST_FILE}" >/dev/null
jq -e '.backup_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
jq -e '.summary.recovery_ready == true' "${PACKET_FILE}" >/dev/null
echo "[OK] backup e restore readiness do odoo comprovados"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase88_odoo_backup_seed.sh
bash -n scripts/phase88_odoo_backup_run.sh
bash -n scripts/phase88_odoo_restore_manifest.sh
bash -n scripts/phase88_odoo_backup_evidence.sh
bash -n scripts/phase88_odoo_backup_packet.sh
bash -n scripts/validate_fase88.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 88 validada"
