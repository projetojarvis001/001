#!/usr/bin/env bash
set -euo pipefail

echo "===== VALIDATE FASE 100 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase100_odoo_closure_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase100_odoo_closure_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== BUILD INVENTORY ====="
./scripts/phase100_odoo_closure_inventory.sh
INVENTORY_FILE="$(ls -1t logs/executive/phase100_odoo_closure_inventory_*.json 2>/dev/null | head -n 1 || true)"
echo "INVENTORY_FILE=${INVENTORY_FILE}"

echo
echo "===== BUILD CONSOLIDATION ====="
./scripts/phase100_odoo_closure_consolidation.sh
CONSOLIDATION_FILE="$(ls -1t logs/executive/phase100_odoo_closure_consolidation_*.json 2>/dev/null | head -n 1 || true)"
echo "CONSOLIDATION_FILE=${CONSOLIDATION_FILE}"

echo
echo "===== BUILD CHECKLIST ====="
./scripts/phase100_odoo_closure_checklist.sh
CHECKLIST_FILE="$(ls -1t logs/executive/phase100_odoo_closure_checklist_*.json 2>/dev/null | head -n 1 || true)"
echo "CHECKLIST_FILE=${CHECKLIST_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase100_odoo_closure_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase100_odoo_closure_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase100_odoo_closure_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase100_odoo_closure_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.closure_inventory.overall_ok == true' "${INVENTORY_FILE}" >/dev/null
jq -e '.consolidation.program_ok == true' "${CONSOLIDATION_FILE}" >/dev/null
jq -e '.checklist.handoff_ready == true' "${CHECKLIST_FILE}" >/dev/null
jq -e '.closure_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] fechamento executivo do watchdog remoto do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase100_odoo_closure_seed.sh
bash -n scripts/phase100_odoo_closure_inventory.sh
bash -n scripts/phase100_odoo_closure_consolidation.sh
bash -n scripts/phase100_odoo_closure_checklist.sh
bash -n scripts/phase100_odoo_closure_evidence.sh
bash -n scripts/phase100_odoo_closure_packet.sh
bash -n scripts/validate_fase100.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 100 validada"
