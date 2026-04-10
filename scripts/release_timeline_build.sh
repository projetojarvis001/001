#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/release_timeline_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" logs/readiness logs/executive

PROMOTION_FILE="${1:-}"
if [ -z "${PROMOTION_FILE}" ]; then
  PROMOTION_FILE="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${PROMOTION_FILE}" ] || [ ! -f "${PROMOTION_FILE}" ]; then
  echo "[ERRO] informe um promotion valido"
  exit 1
fi

READINESS_FILE="$(jq -r '.sources.readiness_file // ""' "${PROMOTION_FILE}")"
RISK_FILE="$(jq -r '.sources.risk_file // ""' "${PROMOTION_FILE}")"
WINDOW_FILE="$(jq -r '.sources.change_window_file // ""' "${PROMOTION_FILE}")"
APPROVAL_FILE="$(jq -r '.sources.approval_file // ""' "${PROMOTION_FILE}")"
DEPLOY_FILE="$(jq -r '.sources.deploy_file // ""' "${PROMOTION_FILE}")"
POST_FILE="$(jq -r '.sources.post_deploy_file // ""' "${PROMOTION_FILE}")"

MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
SEMAPHORE_FILE="$(ls -1t logs/executive/executive_semaphore_*.json 2>/dev/null | head -n 1 || true)"

ROLLBACK_FILE=""
AUTO_ROLLBACK_FILE=""
FREEZE_FILE=""
PROMOTION_FINAL_STATUS="$(jq -r '.result.final_status // "UNKNOWN"' "${PROMOTION_FILE}")"

if [ -n "${MANIFEST_FILE}" ] && [ -f "${MANIFEST_FILE}" ]; then
  FREEZE_FILE="$(jq -r '.sources.freeze_file // ""' "${MANIFEST_FILE}")"
  if [ "${PROMOTION_FINAL_STATUS}" = "ROLLBACK_EXECUTADO" ] || [ "${PROMOTION_FINAL_STATUS}" = "ROLLBACK_FALHOU" ] || [ "${PROMOTION_FINAL_STATUS}" = "FALHA_POS_DEPLOY" ]; then
    ROLLBACK_FILE="$(jq -r '.sources.rollback_file // ""' "${MANIFEST_FILE}")"
    AUTO_ROLLBACK_FILE="$(jq -r '.sources.auto_rollback_file // ""' "${MANIFEST_FILE}")"
  fi
fi

readiness_at=""
readiness_status="NOT_FOUND"
if [ -n "${READINESS_FILE}" ] && [ -f "${READINESS_FILE}" ]; then
  readiness_at="$(jq -r '.created_at // ""' "${READINESS_FILE}")"
  readiness_status="$(jq -r '.readiness // "UNKNOWN"' "${READINESS_FILE}")"
fi

risk_at=""
risk_status="NOT_FOUND"
if [ -n "${RISK_FILE}" ] && [ -f "${RISK_FILE}" ]; then
  risk_at="$(jq -r '.created_at // ""' "${RISK_FILE}")"
  risk_status="$(jq -r '.decision.go_live_status // "UNKNOWN"' "${RISK_FILE}")"
fi

window_at=""
window_status="NOT_FOUND"
if [ -n "${WINDOW_FILE}" ] && [ -f "${WINDOW_FILE}" ]; then
  window_at="$(jq -r '.created_at // ""' "${WINDOW_FILE}")"
  window_status="$(jq -r '.decision.status // "UNKNOWN"' "${WINDOW_FILE}")"
fi

approval_at=""
approval_status="NOT_REQUIRED"
if [ -n "${APPROVAL_FILE}" ] && [ -f "${APPROVAL_FILE}" ]; then
  approval_at="$(jq -r '.created_at // ""' "${APPROVAL_FILE}")"
  if jq -e '.approval.valid == true' "${APPROVAL_FILE}" >/dev/null 2>&1; then
    approval_status="VALID"
  else
    approval_status="INVALID"
  fi
else
  APPROVAL_REQUIRED="$(jq -r '.exception_approval.required // false' "${PROMOTION_FILE}")"
  if [ "${APPROVAL_REQUIRED}" = "true" ]; then
    approval_status="MISSING"
  fi
fi

deploy_at=""
deploy_status="NOT_RUN"
if [ -n "${DEPLOY_FILE}" ] && [ -f "${DEPLOY_FILE}" ]; then
  deploy_at="$(jq -r '.created_at // ""' "${DEPLOY_FILE}")"
  if jq -e '.result.deploy_authorized == true' "${DEPLOY_FILE}" >/dev/null 2>&1; then
    deploy_status="EXECUTADO"
  else
    deploy_status="BLOQUEADO"
  fi
fi

post_at=""
post_status="NOT_RUN"
if [ -n "${POST_FILE}" ] && [ -f "${POST_FILE}" ]; then
  post_at="$(jq -r '.created_at // ""' "${POST_FILE}")"
  post_status="$(jq -r '.result.status // "NOT_RUN"' "${POST_FILE}")"
fi

rollback_at=""
rollback_status="NOT_RUN"
if [ "${PROMOTION_FINAL_STATUS}" = "LIBERAR" ] || [ "${PROMOTION_FINAL_STATUS}" = "LIBERAR_COM_RISCO" ] || [ "${PROMOTION_FINAL_STATUS}" = "BLOQUEAR" ]; then
  rollback_status="NOT_RUN"
  rollback_at=""
elif [ -n "${AUTO_ROLLBACK_FILE}" ] && [ -f "${AUTO_ROLLBACK_FILE}" ]; then
  rollback_at="$(jq -r '.created_at // ""' "${AUTO_ROLLBACK_FILE}")"
  rollback_status="$(jq -r '.result.final_status // "UNKNOWN"' "${AUTO_ROLLBACK_FILE}")"
elif [ -n "${ROLLBACK_FILE}" ] && [ -f "${ROLLBACK_FILE}" ]; then
  rollback_at="$(jq -r '.created_at // ""' "${ROLLBACK_FILE}")"
  if jq -e '.result.rollback_executed == true' "${ROLLBACK_FILE}" >/dev/null 2>&1; then
    rollback_status="EXECUTADO"
  else
    rollback_status="FALHOU"
  fi
else
  rollback_status="$(jq -r '.rollback.status // "NOT_RUN"' "${PROMOTION_FILE}")"
fi

freeze_at=""
freeze_status="NOT_RUN"
if [ -n "${FREEZE_FILE}" ] && [ -f "${FREEZE_FILE}" ]; then
  freeze_at="$(jq -r '.created_at // ""' "${FREEZE_FILE}")"
  if jq -e '.result.freeze_active == true' "${FREEZE_FILE}" >/dev/null 2>&1; then
    freeze_status="ACTIVE"
  else
    freeze_status="INACTIVE"
  fi
fi

promotion_at="$(jq -r '.created_at // ""' "${PROMOTION_FILE}")"
promotion_status="$(jq -r '.result.final_status // "UNKNOWN"' "${PROMOTION_FILE}")"

manifest_at=""
manifest_status="NOT_RUN"
if [ -n "${MANIFEST_FILE}" ] && [ -f "${MANIFEST_FILE}" ]; then
  manifest_at="$(jq -r '.created_at // ""' "${MANIFEST_FILE}")"
  manifest_status="$(jq -r '.execution.final_status // "UNKNOWN"' "${MANIFEST_FILE}")"
fi

semaphore_at=""
semaphore_status="NOT_RUN"
if [ -n "${SEMAPHORE_FILE}" ] && [ -f "${SEMAPHORE_FILE}" ]; then
  semaphore_at="$(jq -r '.created_at // ""' "${SEMAPHORE_FILE}")"
  semaphore_status="$(jq -r '.semaphore.color // "UNKNOWN"' "${SEMAPHORE_FILE}")"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg promotion_file "${PROMOTION_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg semaphore_file "${SEMAPHORE_FILE}" \
  --arg final_status "${promotion_status}" \
  --arg operator_note "Fluxo completo da release consolidado." \
  --arg readiness_at "${readiness_at}" \
  --arg readiness_status "${readiness_status}" \
  --arg risk_at "${risk_at}" \
  --arg risk_status "${risk_status}" \
  --arg window_at "${window_at}" \
  --arg window_status "${window_status}" \
  --arg approval_at "${approval_at}" \
  --arg approval_status "${approval_status}" \
  --arg deploy_at "${deploy_at}" \
  --arg deploy_status "${deploy_status}" \
  --arg post_at "${post_at}" \
  --arg post_status "${post_status}" \
  --arg rollback_at "${rollback_at}" \
  --arg rollback_status "${rollback_status}" \
  --arg freeze_at "${freeze_at}" \
  --arg freeze_status "${freeze_status}" \
  --arg promotion_at "${promotion_at}" \
  --arg promotion_step_status "${promotion_status}" \
  --arg manifest_at "${manifest_at}" \
  --arg manifest_status "${manifest_status}" \
  --arg semaphore_at "${semaphore_at}" \
  --arg semaphore_status "${semaphore_status}" \
  '{
    created_at: $created_at,
    promotion_file: $promotion_file,
    sources: {
      manifest_file: $manifest_file,
      semaphore_file: $semaphore_file
    },
    timeline: [
      {step:"readiness_strict", status:$readiness_status, at:$readiness_at},
      {step:"operational_risk", status:$risk_status, at:$risk_at},
      {step:"change_window", status:$window_status, at:$window_at},
      {step:"exception_approval", status:$approval_status, at:$approval_at},
      {step:"deploy", status:$deploy_status, at:$deploy_at},
      {step:"post_deploy", status:$post_status, at:$post_at},
      {step:"rollback", status:$rollback_status, at:$rollback_at},
      {step:"freeze", status:$freeze_status, at:$freeze_at},
      {step:"promotion", status:$promotion_step_status, at:$promotion_at},
      {step:"manifest", status:$manifest_status, at:$manifest_at},
      {step:"semaphore", status:$semaphore_status, at:$semaphore_at}
    ],
    decision: {
      final_status: $final_status,
      operator_note: $operator_note
    }
  }' > "${OUT_FILE}"

echo "[OK] release timeline gerada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
