#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STATE_DIR="logs/state"
AUDIT_DIR="logs/readiness"
FREEZE_FILE="${STATE_DIR}/change_freeze.state"
OUT_FILE="${AUDIT_DIR}/freeze_event_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${STATE_DIR}" "${AUDIT_DIR}"

RISK_FILE="$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)"
AUTO_ROLLBACK_FILE="$(ls -1t logs/release/auto_rollback_*.json 2>/dev/null | head -n 1 || true)"

FREEZE_ACTIVE=false
FREEZE_REASON="NONE"
FREEZE_SOURCE=""

if [ -n "${RISK_FILE}" ] && [ -f "${RISK_FILE}" ]; then
  RISK_LEVEL="$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")"
  GO_LIVE_STATUS="$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")"

  if [ "${RISK_LEVEL}" = "CRITICAL" ] || [ "${GO_LIVE_STATUS}" = "BLOQUEAR" ]; then
    FREEZE_ACTIVE=true
    FREEZE_REASON="RISK_GATE_BLOCK"
    FREEZE_SOURCE="${RISK_FILE}"
  fi
fi

if [ "${FREEZE_ACTIVE}" != "true" ] && [ -n "${AUTO_ROLLBACK_FILE}" ] && [ -f "${AUTO_ROLLBACK_FILE}" ]; then
  ROLLBACK_EXECUTED="$(jq -r '.result.rollback_executed // false' "${AUTO_ROLLBACK_FILE}")"
  FINAL_STATUS="$(jq -r '.result.final_status // ""' "${AUTO_ROLLBACK_FILE}")"

  if [ "${ROLLBACK_EXECUTED}" = "true" ] || [ "${FINAL_STATUS}" = "ROLLBACK_EXECUTADO" ]; then
    FREEZE_ACTIVE=true
    FREEZE_REASON="AUTO_ROLLBACK_TRIGGERED"
    FREEZE_SOURCE="${AUTO_ROLLBACK_FILE}"
  fi
fi

if [ "${FREEZE_ACTIVE}" = "true" ]; then
  cat > "${FREEZE_FILE}" <<EOF
FREEZE_ACTIVE=1
FREEZE_REASON=${FREEZE_REASON}
FREEZE_SOURCE=${FREEZE_SOURCE}
FREEZE_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
else
  rm -f "${FREEZE_FILE}"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg risk_file "${RISK_FILE}" \
  --arg auto_rollback_file "${AUTO_ROLLBACK_FILE}" \
  --arg freeze_reason "${FREEZE_REASON}" \
  --arg freeze_source "${FREEZE_SOURCE}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  '{
    created_at: $created_at,
    inputs: {
      risk_file: $risk_file,
      auto_rollback_file: $auto_rollback_file
    },
    result: {
      freeze_active: $freeze_active,
      freeze_reason: $freeze_reason,
      freeze_source: $freeze_source
    }
  }' > "${OUT_FILE}"

echo "[OK] freeze event processado"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

if [ "${FREEZE_ACTIVE}" = "true" ]; then
  exit 0
fi

exit 0
