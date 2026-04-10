#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/devops_agent_status_${TS}.json"
OUT_MD="docs/generated/devops_agent_status_${TS}.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
HEAD_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"

COUNTS="$(git rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo '0 0')"
BEHIND_COUNT="$(printf '%s' "${COUNTS}" | awk '{print $1}')"
AHEAD_COUNT="$(printf '%s' "${COUNTS}" | awk '{print $2}')"

WORKTREE_DIRTY=false
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  WORKTREE_DIRTY=true
fi

DOCKER_BIN_OK=false
DOCKER_DAEMON_OK=false
ORBSTACK_OK=false

command -v docker >/dev/null 2>&1 && DOCKER_BIN_OK=true
docker info >/dev/null 2>&1 && DOCKER_DAEMON_OK=true
ps aux | grep -i '[o]rbstack' >/dev/null 2>&1 && ORBSTACK_OK=true

CORE_STATUS="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-jarvis-core-1' | head -n 1 || true)"
REDIS_STATUS="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep '^redis|' | head -n 1 || true)"
POSTGRES_STATUS="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-postgres-1' | head -n 1 || true)"
GRAFANA_STATUS="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-grafana-1' | head -n 1 || true)"
N8N_STATUS="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-n8n-1' | head -n 1 || true)"

AGENT_READY=false
if [ -n "${BRANCH}" ] && [ -n "${HEAD_SHORT}" ] && [ "${DOCKER_DAEMON_OK}" = "true" ]; then
  AGENT_READY=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg head_commit "${HEAD_COMMIT}" \
  --arg head_short "${HEAD_SHORT}" \
  --arg head_subject "${HEAD_SUBJECT}" \
  --arg origin_url "${ORIGIN_URL}" \
  --arg core_status "${CORE_STATUS}" \
  --arg redis_status "${REDIS_STATUS}" \
  --arg postgres_status "${POSTGRES_STATUS}" \
  --arg grafana_status "${GRAFANA_STATUS}" \
  --arg n8n_status "${N8N_STATUS}" \
  --argjson ahead_count "${AHEAD_COUNT}" \
  --argjson behind_count "${BEHIND_COUNT}" \
  --argjson worktree_dirty "${WORKTREE_DIRTY}" \
  --argjson docker_bin_ok "${DOCKER_BIN_OK}" \
  --argjson docker_daemon_ok "${DOCKER_DAEMON_OK}" \
  --argjson orbstack_ok "${ORBSTACK_OK}" \
  --argjson agent_ready "${AGENT_READY}" \
  '{
    created_at: $created_at,
    git: {
      branch: $branch,
      head_commit: $head_commit,
      head_short: $head_short,
      head_subject: $head_subject,
      origin_url: $origin_url,
      ahead_count: $ahead_count,
      behind_count: $behind_count,
      worktree_dirty: $worktree_dirty
    },
    runtime: {
      docker_bin_ok: $docker_bin_ok,
      docker_daemon_ok: $docker_daemon_ok,
      orbstack_ok: $orbstack_ok
    },
    containers: {
      core: $core_status,
      redis: $redis_status,
      postgres: $postgres_status,
      grafana: $grafana_status,
      n8n: $n8n_status
    },
    decision: {
      agent_ready: $agent_ready,
      operator_note:
        (if $agent_ready then
          "DevOps Agent pronto para alteracoes funcionais de baixo risco."
         else
          "DevOps Agent ainda nao esta pronto para avancar com seguranca."
         end)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 66 — DevOps Agent Status

## Git
- branch: ${BRANCH}
- head_short: ${HEAD_SHORT}
- head_subject: ${HEAD_SUBJECT}
- ahead_count: ${AHEAD_COUNT}
- behind_count: ${BEHIND_COUNT}
- worktree_dirty: ${WORKTREE_DIRTY}

## Runtime
- docker_bin_ok: ${DOCKER_BIN_OK}
- docker_daemon_ok: ${DOCKER_DAEMON_OK}
- orbstack_ok: ${ORBSTACK_OK}

## Containers
- core: ${CORE_STATUS}
- redis: ${REDIS_STATUS}
- postgres: ${POSTGRES_STATUS}
- grafana: ${GRAFANA_STATUS}
- n8n: ${N8N_STATUS}

## Decision
- agent_ready: ${AGENT_READY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] devops agent status gerado em ${OUT_JSON}"
echo "[OK] markdown do status gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
