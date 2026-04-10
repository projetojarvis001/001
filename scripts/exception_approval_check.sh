#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/exception_check_$(date +%Y%m%d-%H%M%S).json"
SCOPE="${SCOPE:-promotion_override}"
ACTOR_FILTER="${ACTOR_FILTER:-}"

mkdir -p "${OUT_DIR}"

set +e
ACTOR_FILTER="${ACTOR_FILTER}" ./scripts/exception_approval_resolve.sh "${SCOPE}" >/tmp/exception_resolve.out 2>&1
RESOLVE_RC=$?
set -e

RESOLVE_FILE="$(ls -1t logs/readiness/exception_resolve_*.json 2>/dev/null | head -n 1 || true)"
APPROVAL_FILE=""
APPROVED=false
VALID=false
ACTOR=""
REASON=""
EXPIRES_AT=""
NOTE="Aprovacao excepcional obrigatoria e ausente/invalida."

if [ -n "${RESOLVE_FILE}" ] && [ -f "${RESOLVE_FILE}" ]; then
  APPROVAL_FILE="$(jq -r '.selected_file // ""' "${RESOLVE_FILE}")"
fi

if [ -n "${APPROVAL_FILE}" ] && [ -f "${APPROVAL_FILE}" ] && [ "${RESOLVE_RC}" -eq 0 ]; then
  APPROVED="$(jq -r '.result.approved // false' "${APPROVAL_FILE}")"
  ACTOR="$(jq -r '.actor // ""' "${APPROVAL_FILE}")"
  REASON="$(jq -r '.reason // ""' "${APPROVAL_FILE}")"
  EXPIRES_AT="$(jq -r '.expires_at // ""' "${APPROVAL_FILE}")"

  NOW_EPOCH="$(date -u +%s)"
  EXP_EPOCH="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${EXPIRES_AT}" "+%s" 2>/dev/null || echo 0)"

  if [ "${APPROVED}" = "true" ] && [ "${EXP_EPOCH}" -gt "${NOW_EPOCH}" ]; then
    VALID=true
    NOTE="Aprovacao excepcional vigente."
  fi
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg approval_file "${APPROVAL_FILE}" \
  --arg resolve_file "${RESOLVE_FILE}" \
  --arg approved "${APPROVED}" \
  --arg valid "${VALID}" \
  --arg scope "${SCOPE}" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg expires_at "${EXPIRES_AT}" \
  --arg note "${NOTE}" \
  '{
    created_at: $created_at,
    source: {
      approval_file: $approval_file,
      resolve_file: $resolve_file
    },
    approval: {
      approved: ($approved == "true"),
      valid: ($valid == "true"),
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
