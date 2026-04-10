#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase66_devops_packet_${TS}.json"
OUT_MD="docs/generated/phase66_devops_packet_${TS}.md"

STATUS_FILE="$(ls -1t logs/executive/devops_agent_status_*.json 2>/dev/null | head -n 1 || true)"
PUSH_FILE="$(ls -1t logs/executive/phase65_push_execute_*.json 2>/dev/null | head -n 1 || true)"
VERIFY_FILE="$(ls -1t logs/executive/phase65_post_push_verify_*.json 2>/dev/null | head -n 1 || true)"

BRANCH="$(jq -r '.git.branch // ""' "${STATUS_FILE}" 2>/dev/null || true)"
HEAD_SHORT="$(jq -r '.git.head_short // ""' "${STATUS_FILE}" 2>/dev/null || true)"
WORKTREE_DIRTY="$(jq -r '.git.worktree_dirty // false' "${STATUS_FILE}" 2>/dev/null || true)"
AGENT_READY="$(jq -r '.decision.agent_ready // false' "${STATUS_FILE}" 2>/dev/null || true)"
DOCKER_OK="$(jq -r '.runtime.docker_daemon_ok // false' "${STATUS_FILE}" 2>/dev/null || true)"
REMOTE_MATCH="$(jq -r '.verify.remote_match // false' "${VERIFY_FILE}" 2>/dev/null || true)"
PUSH_EXECUTED="$(jq -r '.governance.push_executed // false' "${PUSH_FILE}" 2>/dev/null || true)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg head_short "${HEAD_SHORT}" \
  --argjson worktree_dirty "${WORKTREE_DIRTY}" \
  --argjson agent_ready "${AGENT_READY}" \
  --argjson docker_ok "${DOCKER_OK}" \
  --argjson remote_match "${REMOTE_MATCH}" \
  --argjson push_executed "${PUSH_EXECUTED}" \
  --arg status_file "${STATUS_FILE}" \
  --arg push_file "${PUSH_FILE}" \
  --arg verify_file "${VERIFY_FILE}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_66_DEVOPS_STATUS",
      branch: $branch,
      head_short: $head_short,
      worktree_dirty: $worktree_dirty,
      docker_ok: $docker_ok,
      remote_match: $remote_match,
      push_executed: $push_executed,
      agent_ready: $agent_ready
    },
    decision: {
      operator_note:
        (if $agent_ready and $remote_match and $docker_ok then
          "Base operacional pronta para primeira alteracao funcional de baixo risco."
         else
          "Base ainda exige ajuste antes da proxima alteracao funcional."
         end)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    },
    sources: {
      status_file: $status_file,
      push_file: $push_file,
      verify_file: $verify_file
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 66 — DevOps Packet

## Summary
- branch: ${BRANCH}
- head_short: ${HEAD_SHORT}
- worktree_dirty: ${WORKTREE_DIRTY}
- docker_ok: ${DOCKER_OK}
- remote_match: ${REMOTE_MATCH}
- push_executed: ${PUSH_EXECUTED}
- agent_ready: ${AGENT_READY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase66 devops packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
