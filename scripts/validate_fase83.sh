#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 83 ====="

echo
echo "===== RUN APPLY ====="
./scripts/phase83_odoo_hardening_apply.sh
APPLY_FILE="$(ls -1t logs/executive/phase83_odoo_hardening_apply_*.json 2>/dev/null | head -n 1 || true)"
echo "APPLY_FILE=${APPLY_FILE}"

echo
echo "===== RUN POST APPLY PROBE ====="
python3 scripts/phase83_odoo_post_apply_probe.py
POST_FILE="$(ls -1t logs/executive/phase83_odoo_post_apply_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "POST_FILE=${POST_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase83_odoo_hardening_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase83_odoo_hardening_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase83_odoo_hardening_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase83_odoo_hardening_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.post_apply_probe.http_ok == true' "${POST_FILE}" >/dev/null
jq -e '.post_apply_probe.auth_ok == true' "${POST_FILE}" >/dev/null
jq -e '.hardening_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] endurecimento inicial do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase83_odoo_hardening_apply.sh
python3 -m py_compile scripts/phase83_odoo_post_apply_probe.py
bash -n scripts/phase83_odoo_hardening_evidence.sh
bash -n scripts/phase83_odoo_hardening_packet.sh
bash -n scripts/validate_fase83.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 83 validada"
