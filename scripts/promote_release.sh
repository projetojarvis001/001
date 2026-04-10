#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/promotion_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" logs/readiness

ACTOR="${ACTOR:-unknown}"
REASON="${REASON:-sem_motivo}"
ALLOW_RISKY_RELEASE="${ALLOW_RISKY_RELEASE:-0}"
ALLOW_OUTSIDE_WINDOW="${ALLOW_OUTSIDE_WINDOW:-0}"

echo "===== PROMOTION PIPELINE ====="

echo
echo "===== STEP 1: READINESS STRICT ====="
./scripts/readiness_gate_strict.sh >/tmp/promote_readiness.out
READINESS_FILE="$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${READINESS_FILE}" ] || [ ! -f "${READINESS_FILE}" ]; then
  echo "[ERRO] readiness strict nao gerado"
  exit 1
fi

STRICT_READINESS="$(jq -r '.readiness // "BLOCKED"' "${READINESS_FILE}")"
STRICT_SCORE="$(jq -r '.score // 0' "${READINESS_FILE}")"

echo "READINESS_FILE=${READINESS_FILE}"
echo "STRICT_READINESS=${STRICT_READINESS}"
echo "STRICT_SCORE=${STRICT_SCORE}"

echo
echo "===== STEP 2: OPERATIONAL RISK ====="
./scripts/operational_risk_gate.sh >/tmp/promote_risk.out
RISK_FILE="$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${RISK_FILE}" ] || [ ! -f "${RISK_FILE}" ]; then
  echo "[ERRO] operational risk nao gerado"
  exit 1
fi

RISK_LEVEL="$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")"
GO_LIVE_STATUS="$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")"
CHANGE_POLICY="$(jq -r '.decision.change_policy // "FREEZE"' "${RISK_FILE}")"
RISK_NOTE="$(jq -r '.decision.operator_note // ""' "${RISK_FILE}")"

echo "RISK_FILE=${RISK_FILE}"
echo "RISK_LEVEL=${RISK_LEVEL}"
echo "GO_LIVE_STATUS=${GO_LIVE_STATUS}"
echo "CHANGE_POLICY=${CHANGE_POLICY}"

echo
echo "===== STEP 3: CHANGE WINDOW ====="
ALLOW_OUTSIDE_WINDOW="${ALLOW_OUTSIDE_WINDOW}" ./scripts/change_window_gate.sh >/tmp/promote_window.out
WINDOW_FILE="$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${WINDOW_FILE}" ] || [ ! -f "${WINDOW_FILE}" ]; then
  echo "[ERRO] change window nao gerado"
  exit 1
fi

WINDOW_STATUS="$(jq -r '.decision.status // "BLOCKED_WINDOW"' "${WINDOW_FILE}")"
WINDOW_AUTHORIZED="$(jq -r '.decision.authorized // false' "${WINDOW_FILE}")"
WINDOW_MODE="$(jq -r '.decision.mode // "NORMAL"' "${WINDOW_FILE}")"
WINDOW_NOTE="$(jq -r '.decision.operator_note // ""' "${WINDOW_FILE}")"

echo "WINDOW_FILE=${WINDOW_FILE}"
echo "WINDOW_STATUS=${WINDOW_STATUS}"
echo "WINDOW_AUTHORIZED=${WINDOW_AUTHORIZED}"
echo "WINDOW_MODE=${WINDOW_MODE}"

FINAL_STATUS="BLOQUEAR"
FINAL_NOTE="Promocao bloqueada."
PROMOTION_AUTHORIZED=false
PROMOTION_MODE="NORMAL"
DEPLOY_EXECUTED=false
DEPLOY_FILE=""

if [ "${WINDOW_AUTHORIZED}" != "true" ]; then
  FINAL_STATUS="BLOQUEAR"
  FINAL_NOTE="Promocao bloqueada pela janela de mudanca: ${WINDOW_NOTE}"
else
  echo
  echo "===== STEP 4: RELEASE GUARD ====="
  if ALLOW_RISKY_RELEASE="${ALLOW_RISKY_RELEASE}" ./scripts/release_guard.sh; then
    echo "[OK] release guard aprovou"

    echo
    echo "===== STEP 5: DEPLOY CONTROLLED ====="
    ACTOR="${ACTOR}" REASON="${REASON}" ALLOW_RISKY_RELEASE="${ALLOW_RISKY_RELEASE}" ./scripts/deploy_controlled.sh
    DEPLOY_FILE="$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)"

    if [ -n "${DEPLOY_FILE}" ] && [ -f "${DEPLOY_FILE}" ]; then
      DEPLOY_EXECUTED=true
      PROMOTION_AUTHORIZED=true
      FINAL_STATUS="${GO_LIVE_STATUS}"
      FINAL_NOTE="${RISK_NOTE}"
      if [ "${ALLOW_RISKY_RELEASE}" = "1" ]; then
        PROMOTION_MODE="OVERRIDE_EXPLICITO"
      else
        PROMOTION_MODE="NORMAL"
      fi
    else
      echo "[ERRO] deploy log nao encontrado"
      exit 1
    fi
  else
    echo "[ERRO] release guard bloqueou"
    FINAL_STATUS="BLOQUEAR"
    FINAL_NOTE="Promocao bloqueada pelo gate de risco/release."
  fi
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg readiness_file "${READINESS_FILE}" \
  --arg risk_file "${RISK_FILE}" \
  --arg window_file "${WINDOW_FILE}" \
  --arg deploy_file "${DEPLOY_FILE}" \
  --arg strict_readiness "${STRICT_READINESS}" \
  --argjson strict_score "${STRICT_SCORE}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --arg change_policy "${CHANGE_POLICY}" \
  --arg risk_note "${RISK_NOTE}" \
  --arg window_status "${WINDOW_STATUS}" \
  --arg window_mode "${WINDOW_MODE}" \
  --arg window_note "${WINDOW_NOTE}" \
  --arg final_status "${FINAL_STATUS}" \
  --arg final_note "${FINAL_NOTE}" \
  --arg promotion_mode "${PROMOTION_MODE}" \
  --arg allow_risky_release "${ALLOW_RISKY_RELEASE}" \
  --arg allow_outside_window "${ALLOW_OUTSIDE_WINDOW}" \
  --argjson promotion_authorized "${PROMOTION_AUTHORIZED}" \
  --argjson deploy_executed "${DEPLOY_EXECUTED}" \
  '{
    created_at: $created_at,
    actor: $actor,
    reason: $reason,
    inputs: {
      allow_risky_release: ($allow_risky_release == "1"),
      allow_outside_window: ($allow_outside_window == "1")
    },
    sources: {
      readiness_file: $readiness_file,
      risk_file: $risk_file,
      change_window_file: $window_file,
      deploy_file: $deploy_file
    },
    readiness: {
      strict_readiness: $strict_readiness,
      strict_score: $strict_score
    },
    risk: {
      risk_level: $risk_level,
      go_live_status: $go_live_status,
      change_policy: $change_policy,
      operator_note: $risk_note
    },
    change_window: {
      status: $window_status,
      mode: $window_mode,
      operator_note: $window_note
    },
    result: {
      promotion_authorized: $promotion_authorized,
      deploy_executed: $deploy_executed,
      final_status: $final_status,
      final_note: $final_note,
      mode: $promotion_mode
    }
  }' > "${OUT_FILE}"

echo
echo "[OK] promotion pipeline concluido"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

AUTHORIZED_STR="$(jq -r '.result.promotion_authorized | tostring' "${OUT_FILE}")"
if [ "${AUTHORIZED_STR}" = "true" ]; then
  exit 0
fi

exit 1
