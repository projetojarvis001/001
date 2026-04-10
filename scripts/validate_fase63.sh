#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 63 ====="

echo
echo "===== BUILD CONTROLLED CHANGE ====="
./scripts/phase63_controlled_change_apply.sh
CHANGE_FILE="$(ls -1t logs/executive/phase63_controlled_change_*.json 2>/dev/null | head -n 1 || true)"
echo "CHANGE_FILE=${CHANGE_FILE}"

echo
echo "===== BUILD REPO DIFF ====="
./scripts/phase63_repo_diff_capture.sh
DIFF_FILE_JSON="$(ls -1t logs/executive/phase63_repo_diff_*.json 2>/dev/null | head -n 1 || true)"
echo "DIFF_FILE_JSON=${DIFF_FILE_JSON}"

echo
echo "===== BUILD PACKET ====="
./scripts/phase63_assisted_change_packet.sh
PACKET_FILE="$(ls -1t logs/executive/phase63_assisted_change_packet_*.json 2>/dev/null | head -n 1 || true)"
echo "PACKET_FILE=${PACKET_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.change.after_exists == true' "${CHANGE_FILE}" >/dev/null
jq -e '.governance.production_changed == false' "${CHANGE_FILE}" >/dev/null
jq -e '.diff.patch_sha256 != ""' "${DIFF_FILE_JSON}" >/dev/null
jq -e '.summary.phase == "FASE_63_ASSISTED_CHANGE"' "${PACKET_FILE}" >/dev/null
jq -e '.governance.deploy_executed == false' "${PACKET_FILE}" >/dev/null
echo "[OK] controlled change consistente"

echo
echo "===== CHECK REPO STATUS ====="
jq -e '.repo.status_short != null' "${DIFF_FILE_JSON}" >/dev/null
jq -e '.summary.branch != ""' "${PACKET_FILE}" >/dev/null
echo "[OK] status do repo capturado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase63_controlled_change_apply.sh
bash -n scripts/phase63_repo_diff_capture.sh
bash -n scripts/phase63_assisted_change_packet.sh
bash -n scripts/validate_fase63.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 63 validada"
