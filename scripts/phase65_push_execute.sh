#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase65_push_execute_${TS}.json"
OUT_MD="docs/generated/phase65_push_execute_${TS}.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
HEAD_BEFORE="$(git rev-parse HEAD 2>/dev/null || true)"
HEAD_SHORT_BEFORE="$(git rev-parse --short HEAD 2>/dev/null || true)"
SUBJECT_BEFORE="$(git log -1 --pretty=%s 2>/dev/null || true)"

git push origin "${BRANCH}" >/tmp/phase65_push.out 2>&1

HEAD_AFTER="$(git rev-parse HEAD 2>/dev/null || true)"
HEAD_SHORT_AFTER="$(git rev-parse --short HEAD 2>/dev/null || true)"
PUSH_OUTPUT="$(cat /tmp/phase65_push.out)"
FETCH_HEAD_REMOTE="$(git ls-remote origin "refs/heads/${BRANCH}" | awk '{print $1}' | head -n 1 || true)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg head_before "${HEAD_BEFORE}" \
  --arg head_short_before "${HEAD_SHORT_BEFORE}" \
  --arg subject_before "${SUBJECT_BEFORE}" \
  --arg head_after "${HEAD_AFTER}" \
  --arg head_short_after "${HEAD_SHORT_AFTER}" \
  --arg remote_head "${FETCH_HEAD_REMOTE}" \
  --arg push_output "${PUSH_OUTPUT}" \
  '{
    created_at: $created_at,
    push: {
      branch: $branch,
      head_before: $head_before,
      head_short_before: $head_short_before,
      subject_before: $subject_before,
      head_after: $head_after,
      head_short_after: $head_short_after,
      remote_head: $remote_head
    },
    governance: {
      push_executed: true,
      deploy_executed: false,
      production_changed: false
    },
    evidence: {
      push_output: $push_output
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 65 — Push Execute

## Push
- branch: ${BRANCH}
- head_short_before: ${HEAD_SHORT_BEFORE}
- head_short_after: ${HEAD_SHORT_AFTER}
- remote_head: ${FETCH_HEAD_REMOTE}

## Governança
- push_executed: true
- deploy_executed: false
- production_changed: false
MD

echo "[OK] push execute gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
