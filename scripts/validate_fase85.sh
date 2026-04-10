#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 85 ====="

echo
echo "===== BUILD SEED ====="
./scripts/phase85_odoo_exposure_seed.sh
SEED_FILE="$(ls -1t logs/executive/phase85_odoo_exposure_seed_*.json 2>/dev/null | head -n 1 || true)"
echo "SEED_FILE=${SEED_FILE}"

echo
echo "===== RUN EXPOSURE PROBE ====="
./scripts/phase85_odoo_exposure_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase85_odoo_exposure_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== RUN EXTERNAL CHECK ====="
./scripts/phase85_odoo_external_check.sh
EXT_FILE="$(ls -1t logs/executive/phase85_odoo_external_check_*.json 2>/dev/null | head -n 1 || true)"
echo "EXT_FILE=${EXT_FILE}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase85_odoo_exposure_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase85_odoo_exposure_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.seed.objective != ""' "${SEED_FILE}" >/dev/null
jq -e '.exposure_probe.raw_file != ""' "${PROBE_FILE}" >/dev/null
jq -e '.external_check.raw_file != ""' "${EXT_FILE}" >/dev/null
jq -e '.summary.proxy_mode != ""' "${PACKET_FILE}" >/dev/null
jq -e '.summary.risk_after != ""' "${PACKET_FILE}" >/dev/null
echo "[OK] diagnostico de exposicao do odoo comprovado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase85_odoo_exposure_seed.sh
bash -n scripts/phase85_odoo_exposure_probe.sh
bash -n scripts/phase85_odoo_external_check.sh
bash -n scripts/phase85_odoo_exposure_packet.sh
bash -n scripts/validate_fase85.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 85 validada"
