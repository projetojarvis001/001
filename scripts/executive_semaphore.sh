#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/executive_semaphore_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" logs/readiness logs/release logs/executive logs/state

READINESS_FILE="$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)"
RISK_FILE="$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)"
WINDOW_FILE="$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)"
APPROVAL_FILE="$(ls -1t logs/readiness/exception_check_*.json 2>/dev/null | head -n 1 || true)"
PROMOTION_FILE="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
POST_FILE="$(ls -1t logs/release/post_deploy_verify_*.json 2>/dev/null | head -n 1 || true)"
AUTO_ROLLBACK_FILE="$(ls -1t logs/release/auto_rollback_*.json 2>/dev/null | head -n 1 || true)"
SCORE_FILE="$(ls -1t logs/executive/operational_score_[0-9]*.json 2>/dev/null | head -n 1 || true)"
TREND_FILE="$(ls -1t logs/executive/operational_score_trend_*.json 2>/dev/null | head -n 1 || true)"

FREEZE_FILE="logs/state/change_freeze.state"
STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{}')"

READINESS="UNKNOWN"
GO_LIVE_STATUS="BLOQUEAR"
RISK_LEVEL="UNKNOWN"
WINDOW_STATUS="UNKNOWN"
APPROVAL_REQUIRED="false"
APPROVAL_VALID="false"
POST_DEPLOY_STATUS="NOT_RUN"
AUTO_ROLLBACK_STATUS="NOT_RUN"
SCORE="0"
TREND="UNKNOWN"
EXECUTIVE_BAND="INDEFINIDA"
FREEZE_ACTIVE=false
STACK_OK=false

if [ -n "${READINESS_FILE}" ] && [ -f "${READINESS_FILE}" ]; then
  READINESS="$(jq -r '.readiness // "UNKNOWN"' "${READINESS_FILE}")"
fi

if [ -n "${RISK_FILE}" ] && [ -f "${RISK_FILE}" ]; then
  GO_LIVE_STATUS="$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")"
  RISK_LEVEL="$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")"
fi

if [ -n "${WINDOW_FILE}" ] && [ -f "${WINDOW_FILE}" ]; then
  WINDOW_STATUS="$(jq -r '.decision.status // "UNKNOWN"' "${WINDOW_FILE}")"
fi

if [ -n "${APPROVAL_FILE}" ] && [ -f "${APPROVAL_FILE}" ]; then
  APPROVAL_REQUIRED="$(jq -r '.approval.scope != ""' "${APPROVAL_FILE}" 2>/dev/null || echo false)"
  APPROVAL_VALID="$(jq -r '.approval.valid // false' "${APPROVAL_FILE}")"
fi

if [ -n "${PROMOTION_FILE}" ] && [ -f "${PROMOTION_FILE}" ]; then
  APPROVAL_REQUIRED="$(jq -r '.exception_approval.required // false' "${PROMOTION_FILE}" 2>/dev/null || echo false)"
  APPROVAL_VALID="$(jq -r '.exception_approval.valid // false' "${PROMOTION_FILE}" 2>/dev/null || echo false)"
fi

if [ -n "${POST_FILE}" ] && [ -f "${POST_FILE}" ]; then
  POST_DEPLOY_STATUS="$(jq -r '.result.status // "NOT_RUN"' "${POST_FILE}")"
fi

if [ -n "${AUTO_ROLLBACK_FILE}" ] && [ -f "${AUTO_ROLLBACK_FILE}" ]; then
  AUTO_ROLLBACK_STATUS="$(jq -r '.result.final_status // "NOT_RUN"' "${AUTO_ROLLBACK_FILE}")"
fi

if [ -n "${SCORE_FILE}" ] && [ -f "${SCORE_FILE}" ]; then
  SCORE="$(jq -r '.scoring.final_score // 0' "${SCORE_FILE}")"
fi

if [ -n "${TREND_FILE}" ] && [ -f "${TREND_FILE}" ]; then
  TREND="$(jq -r '.summary.trend // "UNKNOWN"' "${TREND_FILE}")"
  EXECUTIVE_BAND="$(jq -r '.summary.executive_band // "INDEFINIDA"' "${TREND_FILE}")"
fi

if [ -f "${FREEZE_FILE}" ]; then
  FREEZE_ACTIVE=true
fi

STACK_OK="$(printf "%s" "${STACK_JSON}" | jq -r '.ok // false')"

COLOR="RED"
SEVERITY="CRITICO"
NOTE="Liberacao bloqueada por padrao conservador."

if [ "${FREEZE_ACTIVE}" = "true" ] || [ "${AUTO_ROLLBACK_STATUS}" = "ROLLBACK_FALHOU" ] || [ "${STACK_OK}" != "true" ]; then
  COLOR="BLACK"
  SEVERITY="EMERGENCIA"
  NOTE="Freeze ativo, rollback falho ou stack indisponivel."
elif [ "${READINESS}" != "READY" ] || [ "${GO_LIVE_STATUS}" = "BLOQUEAR" ] || [ "${POST_DEPLOY_STATUS}" = "FAIL" ]; then
  COLOR="RED"
  SEVERITY="CRITICO"
  NOTE="Readiness, risco ou pos-deploy bloqueiam a liberacao."
elif [ "${APPROVAL_REQUIRED}" = "true" ] && [ "${APPROVAL_VALID}" != "true" ]; then
  COLOR="RED"
  SEVERITY="CRITICO"
  NOTE="Aprovacao excepcional obrigatoria e invalida."
elif [ "${GO_LIVE_STATUS}" = "LIBERAR_COM_RISCO" ] || [ "${RISK_LEVEL}" = "HIGH" ] || [ "${SCORE}" -lt 95 ] || [ "${TREND}" = "DOWN" ]; then
  COLOR="YELLOW"
  SEVERITY="ATENCAO"
  NOTE="Liberacao permitida com risco controlado e observacao executiva."
elif [ "${READINESS}" = "READY" ] && [ "${GO_LIVE_STATUS}" = "LIBERAR" ] && [ "${POST_DEPLOY_STATUS}" = "PASS" ] && [ "${SCORE}" -ge 95 ] && [ "${STACK_OK}" = "true" ]; then
  COLOR="GREEN"
  SEVERITY="NORMAL"
  NOTE="Liberacao limpa, operacao sob controle."
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg color "${COLOR}" \
  --arg severity "${SEVERITY}" \
  --arg go_decision "${GO_LIVE_STATUS}" \
  --arg readiness "${READINESS}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg window_status "${WINDOW_STATUS}" \
  --arg approval_required "${APPROVAL_REQUIRED}" \
  --arg approval_valid "${APPROVAL_VALID}" \
  --arg post_deploy_status "${POST_DEPLOY_STATUS}" \
  --arg auto_rollback_status "${AUTO_ROLLBACK_STATUS}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  --argjson score "${SCORE}" \
  --arg trend "${TREND}" \
  --arg executive_band "${EXECUTIVE_BAND}" \
  --argjson stack_ok "${STACK_OK}" \
  --arg operator_note "${NOTE}" \
  '{
    created_at: $created_at,
    semaphore: {
      color: $color,
      severity: $severity,
      go_decision: $go_decision
    },
    inputs: {
      readiness: $readiness,
      risk_level: $risk_level,
      window_status: $window_status,
      approval_required: ($approval_required == "true"),
      approval_valid: ($approval_valid == "true"),
      post_deploy_status: $post_deploy_status,
      auto_rollback_status: $auto_rollback_status,
      freeze_active: $freeze_active,
      score: $score,
      trend: $trend,
      executive_band: $executive_band,
      stack_ok: $stack_ok
    },
    decision: {
      operator_note: $operator_note
    }
  }' > "${OUT_FILE}"

echo "[OK] executive semaphore gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
