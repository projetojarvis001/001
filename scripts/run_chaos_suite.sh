#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/chaos_suite"
OUT_JSON="${OUT_DIR}/chaos_suite_${STAMP}.json"
TMP_JSON="${OUT_DIR}/chaos_suite_${STAMP}.tmp.json"

mkdir -p "${OUT_DIR}"

run_case() {
  NAME="$1"
  CMD="$2"

  echo "===== RUN ${NAME} ====="
  START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if bash -lc "${CMD}"; then
    STATUS="PASS"
  else
    STATUS="FAIL"
  fi

  END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq \
    --arg name "${NAME}" \
    --arg start "${START}" \
    --arg end "${END}" \
    --arg status "${STATUS}" \
    '. + [{"name":$name,"started_at":$start,"finished_at":$end,"status":$status}]' \
    "${TMP_JSON}" > "${TMP_JSON}.2" && mv "${TMP_JSON}.2" "${TMP_JSON}"
}

echo '[]' > "${TMP_JSON}"

run_case "core_down" "./scripts/chaos_test_core_down.sh"
run_case "bridge_down" "./scripts/chaos_test_bridge_down.sh"
run_case "semantic_down" "./scripts/chaos_test_semantic_down.sh"
run_case "whisper_down" "./scripts/chaos_test_whisper_down.sh"

TOTAL=$(jq 'length' "${TMP_JSON}")
PASS=$(jq '[.[] | select(.status=="PASS")] | length' "${TMP_JSON}")
FAIL=$(jq '[.[] | select(.status=="FAIL")] | length' "${TMP_JSON}")

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson total "${TOTAL}" \
  --argjson pass "${PASS}" \
  --argjson fail "${FAIL}" \
  --slurpfile cases "${TMP_JSON}" \
  '{
    created_at: $created_at,
    total: $total,
    pass: $pass,
    fail: $fail,
    status: (if $fail == 0 then "PASS" else "FAIL" end),
    cases: $cases[0]
  }' > "${OUT_JSON}"

rm -f "${TMP_JSON}"

echo "[OK] chaos suite consolidada em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
