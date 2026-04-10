#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/exception_resolve_$(date +%Y%m%d-%H%M%S).json"
REQUESTED_SCOPE="${1:-promotion_override}"
ACTOR_FILTER="${ACTOR_FILTER:-}"

mkdir -p "${OUT_DIR}"

TMP_ITEMS="$(mktemp)"
TOTAL=0
MATCHED_SCOPE=0
VALID_COUNT=0
BEST_FILE=""
BEST_BASENAME=""

for f in logs/readiness/exception_approval_*.json; do
  [ -f "${f}" ] || continue
  TOTAL=$((TOTAL + 1))

  SCOPE="$(jq -r '.scope // ""' "${f}")"
  ACTOR="$(jq -r '.actor // ""' "${f}")"
  REASON="$(jq -r '.reason // ""' "${f}")"
  EXPIRES_AT="$(jq -r '.expires_at // ""' "${f}")"
  APPROVED="$(jq -r '.result.approved // false' "${f}")"

  NOW_EPOCH="$(date -u +%s)"
  EXP_EPOCH="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${EXPIRES_AT}" "+%s" 2>/dev/null || echo 0)"

  VALID=false
  if [ "${APPROVED}" = "true" ] && [ "${EXP_EPOCH}" -gt "${NOW_EPOCH}" ]; then
    VALID=true
  fi

  if [ "${SCOPE}" = "${REQUESTED_SCOPE}" ]; then
    MATCHED_SCOPE=$((MATCHED_SCOPE + 1))

    if [ -z "${ACTOR_FILTER}" ] || [ "${ACTOR}" = "${ACTOR_FILTER}" ]; then
      if [ "${VALID}" = "true" ]; then
        VALID_COUNT=$((VALID_COUNT + 1))
        CURRENT_BASENAME="$(basename "${f}")"
        if [ -z "${BEST_FILE}" ] || [ "${CURRENT_BASENAME}" \> "${BEST_BASENAME}" ]; then
          BEST_FILE="${f}"
          BEST_BASENAME="${CURRENT_BASENAME}"
        fi
      fi
    fi
  fi

  jq -n \
    --arg file "${f}" \
    --arg scope "${SCOPE}" \
    --arg actor "${ACTOR}" \
    --arg reason "${REASON}" \
    --arg expires_at "${EXPIRES_AT}" \
    --arg approved "${APPROVED}" \
    --arg valid "${VALID}" \
    '{
      file: $file,
      scope: $scope,
      actor: $actor,
      reason: $reason,
      expires_at: $expires_at,
      approved: ($approved == "true"),
      valid: ($valid == "true")
    }' >> "${TMP_ITEMS}"
done

jq -s \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg requested_scope "${REQUESTED_SCOPE}" \
  --arg actor_filter "${ACTOR_FILTER}" \
  --arg selected_file "${BEST_FILE}" \
  --argjson total "${TOTAL}" \
  --argjson matched_scope "${MATCHED_SCOPE}" \
  --argjson valid_count "${VALID_COUNT}" \
  '{
    created_at: $created_at,
    requested_scope: $requested_scope,
    actor_filter: $actor_filter,
    summary: {
      total_found: $total,
      matched_scope: $matched_scope,
      valid_count: $valid_count
    },
    selected_file: $selected_file,
    items: .
  }' "${TMP_ITEMS}" > "${OUT_FILE}"

rm -f "${TMP_ITEMS}"

echo "[OK] resolve de approval executado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

if [ -n "${BEST_FILE}" ] && [ -f "${BEST_FILE}" ]; then
  exit 0
fi

exit 1
