#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/operational_score_$(date +%Y%m%d-%H%M%S).json"

SUMMARY_FILE="$(ls -1t logs/executive/daily_change_summary_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
RISK_FILE="$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)"
FREEZE_FILE="logs/state/change_freeze.active"

mkdir -p "${OUT_DIR}"

if [ -z "${SUMMARY_FILE}" ] || [ ! -f "${SUMMARY_FILE}" ]; then
  echo "[ERRO] daily_change_summary inexistente"
  exit 1
fi

if [ -z "${MANIFEST_FILE}" ] || [ ! -f "${MANIFEST_FILE}" ]; then
  echo "[ERRO] release_manifest inexistente"
  exit 1
fi

if [ -z "${RISK_FILE}" ] || [ ! -f "${RISK_FILE}" ]; then
  echo "[ERRO] operational_risk inexistente"
  exit 1
fi

BASE_SCORE=100

RISK_RELEASES="$(jq -r '.releases.risk_releases // 0' "${SUMMARY_FILE}")"
BLOCKED_RELEASES="$(jq -r '.releases.blocked_releases // 0' "${SUMMARY_FILE}")"
ROLLBACK_RELEASES="$(jq -r '.releases.rollback_releases // 0' "${SUMMARY_FILE}")"
FREEZE_ACTIVE="$( [ -f "${FREEZE_FILE}" ] && echo true || echo false )"

GO_LIVE_STATUS="$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")"
RISK_LEVEL="$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")"
POST_DEPLOY_STATUS="$(jq -r '.execution.post_deploy_status // "NOT_RUN"' "${MANIFEST_FILE}")"
FINAL_STATUS="$(jq -r '.execution.final_status // "BLOQUEAR"' "${MANIFEST_FILE}")"
STACK_OK="$(jq -r '.observability.stack_ok // false' "${MANIFEST_FILE}")"

PENALTY_RISK=0
PENALTY_BLOCKED=0
PENALTY_ROLLBACK=0
PENALTY_FREEZE=0
PENALTY_POST=0
PENALTY_STACK=0

[ "${RISK_RELEASES}" -gt 0 ] && PENALTY_RISK=$((RISK_RELEASES * 5))
[ "${BLOCKED_RELEASES}" -gt 0 ] && PENALTY_BLOCKED=$((BLOCKED_RELEASES * 10))
[ "${ROLLBACK_RELEASES}" -gt 0 ] && PENALTY_ROLLBACK=$((ROLLBACK_RELEASES * 20))
[ "${FREEZE_ACTIVE}" = "true" ] && PENALTY_FREEZE=15

if [ "${POST_DEPLOY_STATUS}" != "PASS" ]; then
  PENALTY_POST=10
fi

if [ "${STACK_OK}" != "true" ]; then
  PENALTY_STACK=25
fi

TOTAL_PENALTY=$((PENALTY_RISK + PENALTY_BLOCKED + PENALTY_ROLLBACK + PENALTY_FREEZE + PENALTY_POST + PENALTY_STACK))
FINAL_SCORE=$((BASE_SCORE - TOTAL_PENALTY))

if [ "${FINAL_SCORE}" -lt 0 ]; then
  FINAL_SCORE=0
fi

GRADE="A"
STATUS="EXCELENTE"

if [ "${FINAL_SCORE}" -lt 95 ]; then
  GRADE="B"
  STATUS="BOM"
fi

if [ "${FINAL_SCORE}" -lt 85 ]; then
  GRADE="C"
  STATUS="ATENCAO"
fi

if [ "${FINAL_SCORE}" -lt 70 ]; then
  GRADE="D"
  STATUS="CRITICO"
fi

if [ "${FINAL_SCORE}" -lt 50 ]; then
  GRADE="E"
  STATUS="COLAPSADO"
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg summary_file "${SUMMARY_FILE}" \
  --arg manifest_file "${MANIFEST_FILE}" \
  --arg risk_file "${RISK_FILE}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg post_deploy_status "${POST_DEPLOY_STATUS}" \
  --arg final_status "${FINAL_STATUS}" \
  --arg grade "${GRADE}" \
  --arg status "${STATUS}" \
  --argjson base_score "${BASE_SCORE}" \
  --argjson risk_releases "${RISK_RELEASES}" \
  --argjson blocked_releases "${BLOCKED_RELEASES}" \
  --argjson rollback_releases "${ROLLBACK_RELEASES}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  --argjson stack_ok "${STACK_OK}" \
  --argjson penalty_risk "${PENALTY_RISK}" \
  --argjson penalty_blocked "${PENALTY_BLOCKED}" \
  --argjson penalty_rollback "${PENALTY_ROLLBACK}" \
  --argjson penalty_freeze "${PENALTY_FREEZE}" \
  --argjson penalty_post "${PENALTY_POST}" \
  --argjson penalty_stack "${PENALTY_STACK}" \
  --argjson total_penalty "${TOTAL_PENALTY}" \
  --argjson final_score "${FINAL_SCORE}" \
  '{
    created_at: $created_at,
    sources: {
      summary_file: $summary_file,
      manifest_file: $manifest_file,
      risk_file: $risk_file
    },
    context: {
      go_live_status: $go_live_status,
      risk_level: $risk_level,
      post_deploy_status: $post_deploy_status,
      final_status: $final_status,
      freeze_active: $freeze_active,
      stack_ok: $stack_ok
    },
    counters: {
      risk_releases: $risk_releases,
      blocked_releases: $blocked_releases,
      rollback_releases: $rollback_releases
    },
    scoring: {
      base_score: $base_score,
      penalty_risk: $penalty_risk,
      penalty_blocked: $penalty_blocked,
      penalty_rollback: $penalty_rollback,
      penalty_freeze: $penalty_freeze,
      penalty_post: $penalty_post,
      penalty_stack: $penalty_stack,
      total_penalty: $total_penalty,
      final_score: $final_score,
      grade: $grade,
      status: $status
    },
    decision: {
      operator_note:
        (if $final_score >= 95 then
          "Operacao sob controle, com disciplina forte."
         elif $final_score >= 85 then
          "Operacao boa, mas com pequenos desvios."
         elif $final_score >= 70 then
          "Operacao exige atencao gerencial."
         elif $final_score >= 50 then
          "Operacao em nivel critico. Rever governanca imediatamente."
         else
          "Operacao colapsada para padrao executivo. Congelar mudancas e revisar tudo."
         end)
    }
  }' > "${OUT_FILE}"

echo "[OK] score operacional gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
