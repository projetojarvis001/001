#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATE_DIR="logs/state"
AUDIT_DIR="logs/readiness"
FREEZE_FILE="${STATE_DIR}/change_freeze.state"
OUT_FILE="${AUDIT_DIR}/unfreeze_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${STATE_DIR}" "${AUDIT_DIR}"

ACTOR="${ACTOR:-unknown}"
REASON="${REASON:-sem_motivo}"

WAS_ACTIVE=false
if [ -f "${FREEZE_FILE}" ]; then
  WAS_ACTIVE=true
fi

rm -f "${FREEZE_FILE}"

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --argjson was_active "${WAS_ACTIVE}" \
  '{
    created_at: $created_at,
    actor: $actor,
    reason: $reason,
    result: {
      freeze_removed: true,
      previous_freeze_active: $was_active
    }
  }' > "${OUT_FILE}"

echo "[OK] freeze removido"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
