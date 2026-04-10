#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_ROOT="logs/executive/bundles"
STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE_DIR="${OUT_ROOT}/daily_bundle_${STAMP}"
INDEX_FILE="${BUNDLE_DIR}/index.json"
ARCHIVE_FILE="${OUT_ROOT}/daily_bundle_${STAMP}.tar.gz"

mkdir -p "${BUNDLE_DIR}"

PACKET_FILE="$(ls -1t logs/executive/daily_executive_packet_*.json 2>/dev/null | head -n 1 || true)"
DASH_FILE="logs/executive/executive_ops_dashboard.json"
SUMMARY_FILE="$(ls -1t logs/executive/daily_change_summary_*.json 2>/dev/null | head -n 1 || true)"
SCORE_FILE="$(ls -1t logs/executive/operational_score_[0-9]*.json 2>/dev/null | head -n 1 || true)"
TREND_FILE="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"
SEMAPHORE_FILE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"
RELIABILITY_FILE="$(ls -1t logs/release/release_reliability_*.json 2>/dev/null | head -n 1 || true)"
TIMELINE_FILE="$(ls -1t logs/release/release_timeline_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"

for f in "${PACKET_FILE}" "${DASH_FILE}" "${SUMMARY_FILE}" "${SCORE_FILE}" "${TREND_FILE}" "${SEMAPHORE_FILE}" "${RELIABILITY_FILE}" "${TIMELINE_FILE}" "${MANIFEST_FILE}"; do
  if [ -z "${f}" ] || [ ! -f "${f}" ]; then
    echo "[ERRO] artefato obrigatorio ausente: ${f}"
    exit 1
  fi
done

cp "${PACKET_FILE}" "${BUNDLE_DIR}/"
cp "${DASH_FILE}" "${BUNDLE_DIR}/"
cp "${SUMMARY_FILE}" "${BUNDLE_DIR}/"
cp "${SCORE_FILE}" "${BUNDLE_DIR}/"
cp "${TREND_FILE}" "${BUNDLE_DIR}/"
cp "${SEMAPHORE_FILE}" "${BUNDLE_DIR}/"
cp "${RELIABILITY_FILE}" "${BUNDLE_DIR}/"
cp "${TIMELINE_FILE}" "${BUNDLE_DIR}/"
cp "${MANIFEST_FILE}" "${BUNDLE_DIR}/"

REFERENCE_DAY="$(jq -r '.reference_day // ""' "${PACKET_FILE}")"
EXEC_SIGNAL="$(jq -r '.decision.executive_signal // "UNKNOWN"' "${PACKET_FILE}")"
GO_LIVE_STATUS="$(jq -r '.executive_snapshot.go_live_status // "UNKNOWN"' "${PACKET_FILE}")"
DAY_SCORE="$(jq -r '.operational_discipline.score // 0' "${PACKET_FILE}")"
RELIABILITY_SCORE="$(jq -r '.latest_release.reliability_score // 0' "${PACKET_FILE}")"

checksum_of() {
  local f="$1"
  shasum -a 256 "$f" | awk '{print $1}'
}

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg reference_day "${REFERENCE_DAY}" \
  --arg bundle_dir "${BUNDLE_DIR}" \
  --arg archive_file "${ARCHIVE_FILE}" \
  --arg executive_signal "${EXEC_SIGNAL}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --argjson day_score "${DAY_SCORE}" \
  --argjson reliability_score "${RELIABILITY_SCORE}" \
  --arg packet_file "$(basename "${PACKET_FILE}")" \
  --arg dash_file "$(basename "${DASH_FILE}")" \
  --arg summary_file "$(basename "${SUMMARY_FILE}")" \
  --arg score_file "$(basename "${SCORE_FILE}")" \
  --arg trend_file "$(basename "${TREND_FILE}")" \
  --arg semaphore_file "$(basename "${SEMAPHORE_FILE}")" \
  --arg reliability_file "$(basename "${RELIABILITY_FILE}")" \
  --arg timeline_file "$(basename "${TIMELINE_FILE}")" \
  --arg manifest_file "$(basename "${MANIFEST_FILE}")" \
  --arg packet_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${PACKET_FILE}")")" \
  --arg dash_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${DASH_FILE}")")" \
  --arg summary_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${SUMMARY_FILE}")")" \
  --arg score_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${SCORE_FILE}")")" \
  --arg trend_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${TREND_FILE}")")" \
  --arg semaphore_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${SEMAPHORE_FILE}")")" \
  --arg reliability_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${RELIABILITY_FILE}")")" \
  --arg timeline_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${TIMELINE_FILE}")")" \
  --arg manifest_sha "$(checksum_of "${BUNDLE_DIR}/$(basename "${MANIFEST_FILE}")")" \
  '{
    created_at: $created_at,
    reference_day: $reference_day,
    bundle_dir: $bundle_dir,
    archive_file: $archive_file,
    executive_signal: $executive_signal,
    go_live_status: $go_live_status,
    operational_score: $day_score,
    release_reliability_score: $reliability_score,
    files: [
      {name:$packet_file, sha256:$packet_sha},
      {name:$dash_file, sha256:$dash_sha},
      {name:$summary_file, sha256:$summary_sha},
      {name:$score_file, sha256:$score_sha},
      {name:$trend_file, sha256:$trend_sha},
      {name:$semaphore_file, sha256:$semaphore_sha},
      {name:$reliability_file, sha256:$reliability_sha},
      {name:$timeline_file, sha256:$timeline_sha},
      {name:$manifest_file, sha256:$manifest_sha}
    ]
  }' > "${INDEX_FILE}"

tar -czf "${ARCHIVE_FILE}" -C "${OUT_ROOT}" "$(basename "${BUNDLE_DIR}")"

echo "[OK] bundle executivo gerado em ${BUNDLE_DIR}"
echo "[OK] archive gerado em ${ARCHIVE_FILE}"
cat "${INDEX_FILE}" | jq .
