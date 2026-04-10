#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/release_reliability_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

TIMELINE_FILE="${1:-}"
if [ -z "${TIMELINE_FILE}" ]; then
  TIMELINE_FILE="$(ls -1t logs/release/release_timeline_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${TIMELINE_FILE}" ] || [ ! -f "${TIMELINE_FILE}" ]; then
  echo "[ERRO] informe uma timeline valida"
  exit 1
fi

READINESS_STATUS="$(jq -r '.timeline[] | select(.step == "readiness_strict") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
RISK_STATUS="$(jq -r '.timeline[] | select(.step == "operational_risk") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
WINDOW_STATUS="$(jq -r '.timeline[] | select(.step == "change_window") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
APPROVAL_STATUS="$(jq -r '.timeline[] | select(.step == "exception_approval") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
DEPLOY_STATUS="$(jq -r '.timeline[] | select(.step == "deploy") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
POST_STATUS="$(jq -r '.timeline[] | select(.step == "post_deploy") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
ROLLBACK_STATUS="$(jq -r '.timeline[] | select(.step == "rollback") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
FREEZE_STATUS="$(jq -r '.timeline[] | select(.step == "freeze") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
SEMAPHORE_STATUS="$(jq -r '.timeline[] | select(.step == "semaphore") | .status // "UNKNOWN"' "${TIMELINE_FILE}")"
FINAL_STATUS="$(jq -r '.decision.final_status // "UNKNOWN"' "${TIMELINE_FILE}")"
PROMOTION_FILE="$(jq -r '.promotion_file // ""' "${TIMELINE_FILE}")"

BASE_SCORE=100
PENALTY_RISK=0
PENALTY_WINDOW=0
PENALTY_APPROVAL=0
PENALTY_SEMAPHORE=0
PENALTY_POST=0
PENALTY_ROLLBACK=0
PENALTY_FREEZE=0
PENALTY_DEPLOY=0

if [ "${RISK_STATUS}" = "LIBERAR_COM_RISCO" ]; then
  PENALTY_RISK=10
fi

if [ "${WINDOW_STATUS}" = "OVERRIDE" ]; then
  PENALTY_WINDOW=5
fi

if [ "${APPROVAL_STATUS}" = "VALID" ]; then
  PENALTY_APPROVAL=5
fi

case "${SEMAPHORE_STATUS}" in
  YELLOW) PENALTY_SEMAPHORE=10 ;;
  RED) PENALTY_SEMAPHORE=25 ;;
  BLACK) PENALTY_SEMAPHORE=40 ;;
esac

if [ "${POST_STATUS}" = "FAIL" ]; then
  PENALTY_POST=30
fi

case "${ROLLBACK_STATUS}" in
  EXECUTADO|ROLLBACK_EXECUTADO) PENALTY_ROLLBACK=25 ;;
  FALHOU|ROLLBACK_FALHOU) PENALTY_ROLLBACK=50 ;;
esac

if [ "${FREEZE_STATUS}" = "ACTIVE" ]; then
  PENALTY_FREEZE=30
fi

if [ "${DEPLOY_STATUS}" != "EXECUTADO" ]; then
  PENALTY_DEPLOY=100
fi

TOTAL_PENALTY=$((PENALTY_RISK + PENALTY_WINDOW + PENALTY_APPROVAL + PENALTY_SEMAPHORE + PENALTY_POST + PENALTY_ROLLBACK + PENALTY_FREEZE + PENALTY_DEPLOY))
FINAL_SCORE=$((BASE_SCORE - TOTAL_PENALTY))
if [ "${FINAL_SCORE}" -lt 0 ]; then
  FINAL_SCORE=0
fi

GRADE="E"
STATUS="RELEASE_CRITICA"

if [ "${FINAL_SCORE}" -ge 95 ]; then
  GRADE="A"
  STATUS="RELEASE_FORTE"
elif [ "${FINAL_SCORE}" -ge 85 ]; then
  GRADE="B"
  STATUS="RELEASE_BOA"
elif [ "${FINAL_SCORE}" -ge 70 ]; then
  GRADE="C"
  STATUS="RELEASE_ATENCAO"
elif [ "${FINAL_SCORE}" -ge 50 ]; then
  GRADE="D"
  STATUS="RELEASE_FRAGIL"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg timeline_file "${TIMELINE_FILE}" \
  --arg promotion_file "${PROMOTION_FILE}" \
  --arg readiness_status "${READINESS_STATUS}" \
  --arg risk_status "${RISK_STATUS}" \
  --arg window_status "${WINDOW_STATUS}" \
  --arg approval_status "${APPROVAL_STATUS}" \
  --arg deploy_status "${DEPLOY_STATUS}" \
  --arg post_status "${POST_STATUS}" \
  --arg rollback_status "${ROLLBACK_STATUS}" \
  --arg freeze_status "${FREEZE_STATUS}" \
  --arg semaphore_status "${SEMAPHORE_STATUS}" \
  --arg final_status "${FINAL_STATUS}" \
  --argjson base_score "${BASE_SCORE}" \
  --argjson penalty_risk "${PENALTY_RISK}" \
  --argjson penalty_window "${PENALTY_WINDOW}" \
  --argjson penalty_approval "${PENALTY_APPROVAL}" \
  --argjson penalty_semaphore "${PENALTY_SEMAPHORE}" \
  --argjson penalty_post "${PENALTY_POST}" \
  --argjson penalty_rollback "${PENALTY_ROLLBACK}" \
  --argjson penalty_freeze "${PENALTY_FREEZE}" \
  --argjson penalty_deploy "${PENALTY_DEPLOY}" \
  --argjson total_penalty "${TOTAL_PENALTY}" \
  --argjson final_score "${FINAL_SCORE}" \
  --arg grade "${GRADE}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    sources: {
      timeline_file: $timeline_file,
      promotion_file: $promotion_file
    },
    context: {
      readiness_status: $readiness_status,
      risk_status: $risk_status,
      window_status: $window_status,
      approval_status: $approval_status,
      deploy_status: $deploy_status,
      post_status: $post_status,
      rollback_status: $rollback_status,
      freeze_status: $freeze_status,
      semaphore_status: $semaphore_status,
      final_status: $final_status
    },
    scoring: {
      base_score: $base_score,
      penalty_risk: $penalty_risk,
      penalty_window: $penalty_window,
      penalty_approval: $penalty_approval,
      penalty_semaphore: $penalty_semaphore,
      penalty_post: $penalty_post,
      penalty_rollback: $penalty_rollback,
      penalty_freeze: $penalty_freeze,
      penalty_deploy: $penalty_deploy,
      total_penalty: $total_penalty,
      final_score: $final_score,
      grade: $grade,
      status: $status
    },
    decision: {
      operator_note:
        (if $final_score >= 95 then
          "Release muito forte, com execucao limpa."
         elif $final_score >= 85 then
          "Release boa, mas com concessoes controladas."
         elif $final_score >= 70 then
          "Release aceitavel com pontos de atencao."
         elif $final_score >= 50 then
          "Release fragil. Rever governanca antes de repetir o padrao."
         else
          "Release critica. Fluxo precisa ser revisto antes da proxima promocao."
         end)
    }
  }' > "${OUT_FILE}"

echo "[OK] release reliability gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
