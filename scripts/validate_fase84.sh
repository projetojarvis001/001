#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 84 ====="

echo
echo "===== RUN APPLY ====="
./scripts/phase84_odoo_surface_reduce_apply.sh
APPLY_FILE="$(ls -1t logs/executive/phase84_odoo_surface_reduce_apply_*.json 2>/dev/null | head -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== RUN POST PROBE ====="
python3 scripts/phase84_odoo_post_surface_probe.py
POST_FILE="$(ls -1t logs/executive/phase84_odoo_post_surface_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "POST_FILE=${POST_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase84_odoo_surface_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase84_odoo_surface_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase84_odoo_surface_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase84_odoo_surface_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.apply.list_db_set == true' "${APPLY_FILE}" >/dev/null
jq -e '.post_surface_probe.http_ok == true' "${POST_FILE}" >/dev/null
jq -e '.post_surface_probe.auth_ok == true' "${POST_FILE}" >/dev/null
jq -e '.surface_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] reducao inicial de superficie do odoo comprovada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase84_odoo_surface_reduce_apply.sh
python3 -m py_compile scripts/phase84_odoo_post_surface_probe.py
bash -n scripts/phase84_odoo_surface_evidence.sh
bash -n scripts/phase84_odoo_surface_packet.sh
bash -n scripts/validate_fase84.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 84 validada"
