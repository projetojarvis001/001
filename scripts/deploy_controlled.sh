#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/release_$(date +%Y%m%d-%H%M%S).json"
mkdir -p "${OUT_DIR}"

ACTOR="${ACTOR:-jarvis001}"
REASON="${REASON:-deploy_controlado}"
ALLOW_RISKY_RELEASE="${ALLOW_RISKY_RELEASE:-0}"

RISK_FILE=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)
READINESS_FILE=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)

if [ -z "${RISK_FILE}" ] || [ ! -f "${RISK_FILE}" ]; then
  echo "[ERRO] sem operational_risk para deploy"
  exit 1
fi

./scripts/release_guard.sh

GO_LIVE_STATUS=$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")
RISK_LEVEL=$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")
CHANGE_POLICY=$(jq -r '.decision.change_policy // "FREEZE"' "${RISK_FILE}")
OPERATOR_NOTE=$(jq -r '.decision.operator_note // "Sem nota"' "${RISK_FILE}")

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg allow_risky_release "${ALLOW_RISKY_RELEASE}" \
  --arg risk_file "${RISK_FILE}" \
  --arg readiness_file "${READINESS_FILE}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg change_policy "${CHANGE_POLICY}" \
  --arg operator_note "${OPERATOR_NOTE}" \
  '{
    created_at: $created_at,
    actor: $actor,
    reason: $reason,
    allow_risky_release: ($allow_risky_release == "1"),
    inputs: {
      risk_file: $risk_file,
      readiness_file: $readiness_file
    },
    decision: {
      go_live_status: $go_live_status,
      risk_level: $risk_level,
      change_policy: $change_policy,
      operator_note: $operator_note
    },
    result: {
      deploy_authorized: true,
      mode: (if ($allow_risky_release == "1") then "OVERRIDE_EXPLICITO" else "NORMAL" end)
    }
  }' > "${OUT_FILE}"

echo "[OK] deploy autorizado"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
