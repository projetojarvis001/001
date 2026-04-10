#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
ARCHIVE_DIR="logs/readiness/expired_exception_approvals"
OUT_FILE="${OUT_DIR}/exception_cleanup_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" "${ARCHIVE_DIR}"

now_epoch() {
  date +%s
}

iso_to_epoch() {
  local iso="$1"
  if [ -z "${iso}" ] || [ "${iso}" = "null" ]; then
    echo 0
    return 0
  fi
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${iso}" "+%s" 2>/dev/null || echo 0
}

TOTAL=0
ACTIVE=0
EXPIRED=0
MOVED=0

TMP_ITEMS="$(mktemp)"
: > "${TMP_ITEMS}"

for f in logs/readiness/exception_approval_*.json; do
  [ -e "${f}" ] || continue
  TOTAL=$((TOTAL + 1))

  EXPIRES_AT="$(jq -r '.expires_at // ""' "${f}" 2>/dev/null || echo "")"
  ACTOR="$(jq -r '.actor // "unknown"' "${f}" 2>/dev/null || echo "unknown")"
  REASON="$(jq -r '.reason // ""' "${f}" 2>/dev/null || echo "")"
  SCOPE="$(jq -r '.scope // ""' "${f}" 2>/dev/null || echo "")"

  EXP_EPOCH="$(iso_to_epoch "${EXPIRES_AT}")"
  NOW_EPOCH="$(now_epoch)"

  STATUS="ACTIVE"
  TARGET=""

  if [ "${EXP_EPOCH}" -gt 0 ] && [ "${EXP_EPOCH}" -lt "${NOW_EPOCH}" ]; then
    STATUS="EXPIRED"
    EXPIRED=$((EXPIRED + 1))
    TARGET="${ARCHIVE_DIR}/$(basename "${f}")"
    mv "${f}" "${TARGET}"
    MOVED=$((MOVED + 1))
  else
    ACTIVE=$((ACTIVE + 1))
  fi

  jq -n \
    --arg file "$(basename "${f}")" \
    --arg actor "${ACTOR}" \
    --arg reason "${REASON}" \
    --arg scope "${SCOPE}" \
    --arg expires_at "${EXPIRES_AT}" \
    --arg status "${STATUS}" \
    --arg target "${TARGET}" \
    '{
      file: $file,
      actor: $actor,
      reason: $reason,
      scope: $scope,
      expires_at: $expires_at,
      status: $status,
      archived_to: $target
    }' >> "${TMP_ITEMS}"
done

jq -s \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson total "${TOTAL}" \
  --argjson active "${ACTIVE}" \
  --argjson expired "${EXPIRED}" \
  --argjson moved "${MOVED}" \
  '{
    created_at: $created_at,
    summary: {
      total_found: $total,
      active: $active,
      expired: $expired,
      moved_to_archive: $moved
    },
    items: .
  }' "${TMP_ITEMS}" > "${OUT_FILE}"

rm -f "${TMP_ITEMS}"

echo "[OK] cleanup de approvals executado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
