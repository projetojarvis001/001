#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/release_manifest_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}" logs/readiness logs/state

PROMOTION_FILE="${1:-}"
if [ -z "${PROMOTION_FILE}" ]; then
  PROMOTION_FILE="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${PROMOTION_FILE}" ] || [ ! -f "${PROMOTION_FILE}" ]; then
  echo "[ERRO] informe um promotion log valido"
  exit 1
fi

READINESS_FILE="$(jq -r '.sources.readiness_file // ""' "${PROMOTION_FILE}")"
RISK_FILE="$(jq -r '.sources.risk_file // ""' "${PROMOTION_FILE}")"
WINDOW_FILE="$(jq -r '.sources.change_window_file // ""' "${PROMOTION_FILE}")"
APPROVAL_FILE="$(jq -r '.sources.approval_file // ""' "${PROMOTION_FILE}")"
DEPLOY_FILE="$(jq -r '.sources.deploy_file // ""' "${PROMOTION_FILE}")"
POST_DEPLOY_FILE="$(jq -r '.sources.post_deploy_file // ""' "${PROMOTION_FILE}")"

ROLLBACK_FILE="$(ls -1t logs/release/rollback_*.json 2>/dev/null | head -n 1 || true)"
AUTO_ROLLBACK_FILE="$(ls -1t logs/release/auto_rollback_*.json 2>/dev/null | head -n 1 || true)"
FREEZE_FILE="logs/state/CHANGE_FREEZE.active"

PROMO_CREATED_AT="$(jq -r '.created_at // ""' "${PROMOTION_FILE}")"
ACTOR="$(jq -r '.actor // "unknown"' "${PROMOTION_FILE}")"
REASON="$(jq -r '.reason // "sem_motivo"' "${PROMOTION_FILE}")"

STRICT_READINESS="$(jq -r '.readiness.strict_readiness // "UNKNOWN"' "${PROMOTION_FILE}")"
STRICT_SCORE="$(jq -r '.readiness.strict_score // 0' "${PROMOTION_FILE}")"

RISK_LEVEL="$(jq -r '.risk.risk_level // "UNKNOWN"' "${PROMOTION_FILE}")"
GO_LIVE_STATUS="$(jq -r '.risk.go_live_status // "BLOQUEAR"' "${PROMOTION_FILE}")"
CHANGE_POLICY="$(jq -r '.risk.change_policy // "FREEZE"' "${PROMOTION_FILE}")"
RISK_NOTE="$(jq -r '.risk.operator_note // ""' "${PROMOTION_FILE}")"

WINDOW_STATUS="$(jq -r '.change_window.status // "UNKNOWN"' "${PROMOTION_FILE}")"
WINDOW_MODE="$(jq -r '.change_window.mode // "UNKNOWN"' "${PROMOTION_FILE}")"
WINDOW_NOTE="$(jq -r '.change_window.operator_note // ""' "${PROMOTION_FILE}")"

APPROVAL_REQUIRED="$(jq -r '.exception_approval.required // false' "${PROMOTION_FILE}")"
APPROVAL_VALID="$(jq -r '.exception_approval.valid // false' "${PROMOTION_FILE}")"
APPROVAL_NOTE="$(jq -r '.exception_approval.operator_note // ""' "${PROMOTION_FILE}")"

POST_DEPLOY_STATUS="$(jq -r '.post_deploy.status // "NOT_RUN"' "${PROMOTION_FILE}")"
POST_DEPLOY_NOTE="$(jq -r '.post_deploy.operator_note // ""' "${PROMOTION_FILE}")"

ROLLBACK_STATUS="$(jq -r '.rollback.status // "NOT_RUN"' "${PROMOTION_FILE}")"
ROLLBACK_NOTE="$(jq -r '.rollback.operator_note // ""' "${PROMOTION_FILE}")"

PROMOTION_AUTHORIZED="$(jq -r '.result.promotion_authorized // false' "${PROMOTION_FILE}")"
DEPLOY_EXECUTED="$(jq -r '.result.deploy_executed // false' "${PROMOTION_FILE}")"
FINAL_STATUS="$(jq -r '.result.final_status // "BLOQUEAR"' "${PROMOTION_FILE}")"
FINAL_NOTE="$(jq -r '.result.final_note // ""' "${PROMOTION_FILE}")"
PROMOTION_MODE="$(jq -r '.result.mode // "NORMAL"' "${PROMOTION_FILE}")"

STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{}')"
SLO_JSON="$(curl -fsS http://127.0.0.1:3000/stack/slo || echo '{}')"
HISTORY_JSON="$(curl -fsS http://127.0.0.1:3000/stack/history/compact || echo '{}')"

GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
GIT_TAG="$(git describe --tags --exact-match 2>/dev/null || echo "")"

FREEZE_ACTIVE=false
if [ -f "${FREEZE_FILE}" ]; then
  FREEZE_ACTIVE=true
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg promotion_file "${PROMOTION_FILE}" \
  --arg readiness_file "${READINESS_FILE}" \
  --arg risk_file "${RISK_FILE}" \
  --arg window_file "${WINDOW_FILE}" \
  --arg approval_file "${APPROVAL_FILE}" \
  --arg deploy_file "${DEPLOY_FILE}" \
  --arg post_deploy_file "${POST_DEPLOY_FILE}" \
  --arg rollback_file "${ROLLBACK_FILE}" \
  --arg auto_rollback_file "${AUTO_ROLLBACK_FILE}" \
  --arg freeze_file "${FREEZE_FILE}" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg promotion_created_at "${PROMO_CREATED_AT}" \
  --arg strict_readiness "${STRICT_READINESS}" \
  --argjson strict_score "${STRICT_SCORE}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --arg change_policy "${CHANGE_POLICY}" \
  --arg risk_note "${RISK_NOTE}" \
  --arg window_status "${WINDOW_STATUS}" \
  --arg window_mode "${WINDOW_MODE}" \
  --arg window_note "${WINDOW_NOTE}" \
  --arg approval_required "${APPROVAL_REQUIRED}" \
  --arg approval_valid "${APPROVAL_VALID}" \
  --arg approval_note "${APPROVAL_NOTE}" \
  --arg post_deploy_status "${POST_DEPLOY_STATUS}" \
  --arg post_deploy_note "${POST_DEPLOY_NOTE}" \
  --arg rollback_status "${ROLLBACK_STATUS}" \
  --arg rollback_note "${ROLLBACK_NOTE}" \
  --arg promotion_authorized "${PROMOTION_AUTHORIZED}" \
  --arg deploy_executed "${DEPLOY_EXECUTED}" \
  --arg final_status "${FINAL_STATUS}" \
  --arg final_note "${FINAL_NOTE}" \
  --arg promotion_mode "${PROMOTION_MODE}" \
  --arg git_commit "${GIT_COMMIT}" \
  --arg git_branch "${GIT_BRANCH}" \
  --arg git_tag "${GIT_TAG}" \
  --argjson freeze_active "${FREEZE_ACTIVE}" \
  --argjson stack "${STACK_JSON}" \
  --argjson slo "${SLO_JSON}" \
  --argjson hist "${HISTORY_JSON}" \
  '{
    created_at: $created_at,
    release_identity: {
      actor: $actor,
      reason: $reason,
      promotion_created_at: $promotion_created_at,
      promotion_mode: $promotion_mode
    },
    sources: {
      promotion_file: $promotion_file,
      readiness_file: $readiness_file,
      risk_file: $risk_file,
      change_window_file: $window_file,
      approval_file: $approval_file,
      deploy_file: $deploy_file,
      post_deploy_file: $post_deploy_file,
      rollback_file: $rollback_file,
      auto_rollback_file: $auto_rollback_file,
      freeze_file: (if $freeze_active then $freeze_file else "" end)
    },
    governance: {
      strict_readiness: $strict_readiness,
      strict_score: ($strict_score | tonumber),
      risk_level: $risk_level,
      go_live_status: $go_live_status,
      change_policy: $change_policy,
      change_window_status: $window_status,
      change_window_mode: $window_mode,
      exception_approval_required: ($approval_required == "true"),
      exception_approval_valid: ($approval_valid == "true"),
      freeze_active: $freeze_active
    },
    execution: {
      promotion_authorized: ($promotion_authorized == "true"),
      deploy_executed: ($deploy_executed == "true"),
      post_deploy_status: $post_deploy_status,
      rollback_status: $rollback_status,
      final_status: $final_status,
      final_note: $final_note
    },
    notes: {
      risk_note: $risk_note,
      window_note: $window_note,
      approval_note: $approval_note,
      post_deploy_note: $post_deploy_note,
      rollback_note: $rollback_note
    },
    observability: {
      stack_ok: ($stack.ok // false),
      slo_today_percent: ($slo.availability_percent // 0),
      availability_7d_percent: ($hist.summary.average_availability_percent_7d // 0),
      downtime_7d_seconds: ($hist.summary.total_downtime_seconds_7d // 0),
      incidents_7d: ($hist.summary.total_incidents_7d // 0),
      executive_status: ($hist.summary.executive_status // "INDEFINIDO"),
      trend_7d: ($hist.summary.trend_7d // "UNKNOWN")
    },
    git: {
      branch: $git_branch,
      commit: $git_commit,
      tag: $git_tag
    }
  }' > "${OUT_FILE}"

echo "[OK] release manifest gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
