#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/exception_check_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

APPROVAL_FILE="$(ls -1t logs/readiness/exception_approval_*.json 2>/dev/null | head -n 1 || true)"

APPROVED=false
VALID=false
SCOPE=""
ACTOR=""
REASON=""
EXPIRES_AT=""
NOTE="Sem aprovacao vigente."

if [ -n "${APPROVAL_FILE}" ] && [ -f "${APPROVAL_FILE}" ]; then
  APPROVED="$(jq -r '.result.approved // false' "${APPROVAL_FILE}")"
  SCOPE="$(jq -r '.scope // ""' "${APPROVAL_FILE}")"
  ACTOR="$(jq -r '.actor // ""' "${APPROVAL_FILE}")"
  REASON="$(jq -r '.reason // ""' "${APPROVAL_FILE}")"
  EXPIRES_AT="$(jq -r '.expires_at // ""' "${APPROVAL_FILE}")"

  NOW_EPOCH="$(date -u +%s)"
  EXP_EPOCH="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${EXPIRES_AT}" "+%s" 2>/dev/null || echo 0)"

  if [ "${APPROVED}" = "true" ] && [ "${EXP_EPOCH}" -gt "${NOW_EPOCH}" ]; then
    VALID=true
    NOTE="Aprovacao excepcional vigente."
  else
    NOTE="Aprovacao encontrada, mas expirada ou invalida."
  fi
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg approval_file "${APPROVAL_FILE}" \
  --arg scope "${SCOPE}" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg expires_at "${EXPIRES_AT}" \
  --arg note "${NOTE}" \
  --argjson approved "${APPROVED}" \
  --argjson valid "${VALID}" \
  '{
    created_at: $created_at,
    source: {
      approval_file: $approval_file
    },
    approval: {
      approved: $approved,
      valid: $valid,
      scope: $scope,
      actor: $actor,
      reason: $reason,
      expires_at: $expires_at
    },
    result: {
      note: $note
    }
  }' > "${OUT_FILE}"

echo "[OK] exception approval check gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

if [ "${VALID}" = "true" ]; then
  exit 0
fi

exit 1
