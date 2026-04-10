#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
BUNDLES_DIR="logs/executive/bundles"
OUT_FILE="${OUT_DIR}/audit_bundle_index.json"
TMP_FILE="/tmp/audit_bundle_index_$$.json"

mkdir -p "${OUT_DIR}" "${BUNDLES_DIR}"

printf '[]\n' > "${TMP_FILE}"

find "${BUNDLES_DIR}" -type f -path '*/index.json' | sort | while read -r INDEX_FILE; do
  BUNDLE_DIR="$(dirname "${INDEX_FILE}")"
  REF_DAY="$(jq -r '.reference_day // ""' "${INDEX_FILE}")"
  ARCHIVE_FILE="$(jq -r '.archive_file // ""' "${INDEX_FILE}")"
  EXEC_SIGNAL="$(jq -r '.executive_signal // "UNKNOWN"' "${INDEX_FILE}")"
  GO_LIVE_STATUS="$(jq -r '.go_live_status // "UNKNOWN"' "${INDEX_FILE}")"
  OP_SCORE="$(jq -r '.operational_score // 0' "${INDEX_FILE}")"
  REL_SCORE="$(jq -r '.release_reliability_score // 0' "${INDEX_FILE}")"
  INDEX_SHA="$(shasum -a 256 "${INDEX_FILE}" | awk '{print $1}')"

  ARCHIVE_OK=false
  if [ -n "${ARCHIVE_FILE}" ] && [ -f "${ARCHIVE_FILE}" ]; then
    if tar -tzf "${ARCHIVE_FILE}" >/dev/null 2>&1; then
      ARCHIVE_OK=true
    fi
  fi

  jq \
    --arg reference_day "${REF_DAY}" \
    --arg bundle_dir "${BUNDLE_DIR}" \
    --arg archive_file "${ARCHIVE_FILE}" \
    --arg executive_signal "${EXEC_SIGNAL}" \
    --arg go_live_status "${GO_LIVE_STATUS}" \
    --argjson operational_score "${OP_SCORE}" \
    --argjson release_reliability_score "${REL_SCORE}" \
    --arg index_sha256 "${INDEX_SHA}" \
    --argjson archive_ok "${ARCHIVE_OK}" \
    '
    map(select(.bundle_dir != $bundle_dir)) +
    [
      {
        reference_day: $reference_day,
        bundle_dir: $bundle_dir,
        archive_file: $archive_file,
        executive_signal: $executive_signal,
        go_live_status: $go_live_status,
        operational_score: $operational_score,
        release_reliability_score: $release_reliability_score,
        index_sha256: $index_sha256,
        archive_ok: $archive_ok
      }
    ]
    ' "${TMP_FILE}" > "${TMP_FILE}.next"

  mv "${TMP_FILE}.next" "${TMP_FILE}"
done

jq 'sort_by(.reference_day, .bundle_dir)' "${TMP_FILE}" > "${OUT_FILE}"
rm -f "${TMP_FILE}"

echo "[OK] audit bundle index atualizado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
