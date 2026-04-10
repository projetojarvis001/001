#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase65_push_audit_${TS}.json"
OUT_MD="docs/generated/phase65_push_audit_${TS}.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
HEAD_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
WORKTREE_DIRTY=false
AHEAD_COUNT=0
BEHIND_COUNT=0

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  WORKTREE_DIRTY=true
fi

COUNTS="$(git rev-list --left-right --count origin/main...HEAD 2>/dev/null || echo '0 0')"
BEHIND_COUNT="$(printf '%s' "${COUNTS}" | awk '{print $1}')"
AHEAD_COUNT="$(printf '%s' "${COUNTS}" | awk '{print $2}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg head_commit "${HEAD_COMMIT}" \
  --arg head_short "${HEAD_SHORT}" \
  --arg head_subject "${HEAD_SUBJECT}" \
  --arg origin_url "${ORIGIN_URL}" \
  --argjson worktree_dirty "${WORKTREE_DIRTY}" \
  --argjson ahead_count "${AHEAD_COUNT}" \
  --argjson behind_count "${BEHIND_COUNT}" \
  '{
    created_at: $created_at,
    repo: {
      branch: $branch,
      head_commit: $head_commit,
      head_short: $head_short,
      head_subject: $head_subject,
      origin_url: $origin_url
    },
    sync: {
      worktree_dirty: $worktree_dirty,
      ahead_count: $ahead_count,
      behind_count: $behind_count
    },
    governance: {
      deploy_executed: false,
      push_candidate: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 65 — Push Audit

## Repo
- branch: ${BRANCH}
- head_short: ${HEAD_SHORT}
- head_subject: ${HEAD_SUBJECT}
- origin_url: ${ORIGIN_URL}

## Sync
- worktree_dirty: ${WORKTREE_DIRTY}
- ahead_count: ${AHEAD_COUNT}
- behind_count: ${BEHIND_COUNT}

## Governança
- deploy_executed: false
- push_candidate: true
MD

echo "[OK] push audit gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
