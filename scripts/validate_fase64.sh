#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 64 ====="

echo
echo "===== BUILD TRACKED CHANGE ====="
./scripts/phase64_tracked_change_apply.sh
CHANGE_FILE="$(ls -1t logs/executive/phase64_tracked_change_*.json 2>/dev/null | head -n 1 || true)"
echo "CHANGE_FILE=${CHANGE_FILE}"

echo
echo "===== BUILD TRACKED DIFF ====="
./scripts/phase64_tracked_diff_capture.sh
DIFF_FILE_JSON="$(ls -1t logs/executive/phase64_tracked_diff_*.json 2>/dev/null | head -n 1 || true)"
echo "DIFF_FILE_JSON=${DIFF_FILE_JSON}"

echo
echo "===== BUILD LOCAL COMMIT ====="
./scripts/phase64_local_commit_controlled.sh
COMMIT_FILE="$(ls -1t logs/executive/phase64_local_commit_*.json 2>/dev/null | head -n 1 || true)"
echo "COMMIT_FILE=${COMMIT_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.change.after_exists == true' "${CHANGE_FILE}" >/dev/null
jq -e '.diff.patch_lines > 0' "${DIFF_FILE_JSON}" >/dev/null
jq -e '.commit.new_commit_short != ""' "${COMMIT_FILE}" >/dev/null
jq -e '.governance.commit_executed == true' "${COMMIT_FILE}" >/dev/null
jq -e '.governance.push_executed == false' "${COMMIT_FILE}" >/dev/null
echo "[OK] fase 64 consistente"

echo
echo "===== CHECK REVERSIBILIDADE ====="
jq -e '.commit.revert_cmd != ""' "${COMMIT_FILE}" >/dev/null
echo "[OK] commit reversivel registrado"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase64_tracked_change_apply.sh
bash -n scripts/phase64_tracked_diff_capture.sh
bash -n scripts/phase64_local_commit_controlled.sh
bash -n scripts/validate_fase64.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 64 validada"
