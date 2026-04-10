#!/usr/bin/env bash
set -e

echo "===== VALIDATE FASE 86 FINAL ====="

echo
echo "===== RUN POST PROBE ====="
python3 scripts/phase86_odoo_post_proxy_probe.py
POST_FILE="$(ls -1t logs/executive/phase86_odoo_post_proxy_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "POST_FILE=${POST_FILE}"

echo
echo "===== BUILD EVIDENCE ====="
./scripts/phase86_final_odoo_proxy_evidence.sh
EVIDENCE_FILE="$(ls -1t logs/executive/phase86_final_odoo_proxy_evidence_*.json 2>/dev/null | head -n 1 || true)"
echo "EVIDENCE_FILE=${EVIDENCE_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase86_final_odoo_proxy_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase86_final_odoo_proxy_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.post_proxy_probe.http_ok == true' "${POST_FILE}" >/dev/null
jq -e '.post_proxy_probe.auth_ok == true' "${POST_FILE}" >/dev/null
jq -e '.proxy_final_flow.header_is_nginx == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.proxy_final_flow.flow_ok == true' "${EVIDENCE_FILE}" >/dev/null
jq -e '.summary.flow_ok == true' "${PACKET_FILE}" >/dev/null
echo "[OK] proxy real do odoo finalmente comprovado"

echo
echo "===== SANIDADE ====="
python3 -m py_compile scripts/phase86_odoo_post_proxy_probe.py
bash -n scripts/phase86_final_odoo_proxy_evidence.sh
bash -n scripts/phase86_final_odoo_proxy_packet.sh
bash -n scripts/validate_fase86_final.sh
echo "[OK] sintaxe shell/python valida"

echo
echo "[OK] fase 86 final validada"
