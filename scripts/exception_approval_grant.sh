#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/exception_approval_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

ACTOR="${ACTOR:-unknown}"
REASON="${REASON:-sem_motivo}"
SCOPE="${SCOPE:-promotion_override}"
TTL_MINUTES="${TTL_MINUTES:-30}"

EXPIRES_AT="$(date -u -v+"${TTL_MINUTES}"M +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg scope "${SCOPE}" \
  --arg expires_at "${EXPIRES_AT}" \
  --argjson ttl_minutes "${TTL_MINUTES}" \
  '{
    created_at: $created_at,
    actor: $actor,
    reason: $reason,
    scope: $scope,
    ttl_minutes: $ttl_minutes,
    expires_at: $expires_at,
    result: {
      approved: true
    }
  }' > "${OUT_FILE}"

echo "[OK] exception approval concedida"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
