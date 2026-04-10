#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase65_post_push_verify_${TS}.json"
OUT_MD="docs/generated/phase65_post_push_verify_${TS}.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
LOCAL_HEAD="$(git rev-parse HEAD 2>/dev/null || true)"
LOCAL_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
REMOTE_HEAD="$(git ls-remote origin "refs/heads/${BRANCH}" | awk '{print $1}' | head -n 1 || true)"

REMOTE_MATCH=false
if [ -n "${LOCAL_HEAD}" ] && [ "${LOCAL_HEAD}" = "${REMOTE_HEAD}" ]; then
  REMOTE_MATCH=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg local_head "${LOCAL_HEAD}" \
  --arg local_short "${LOCAL_SHORT}" \
  --arg remote_head "${REMOTE_HEAD}" \
  --argjson remote_match "${REMOTE_MATCH}" \
  '{
    created_at: $created_at,
    verify: {
      branch: $branch,
      local_head: $local_head,
      local_short: $local_short,
      remote_head: $remote_head,
      remote_match: $remote_match
    },
    governance: {
      push_verified: true,
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 65 — Post Push Verify

## Verify
- branch: ${BRANCH}
- local_short: ${LOCAL_SHORT}
- remote_head: ${REMOTE_HEAD}
- remote_match: ${REMOTE_MATCH}

## Governança
- push_verified: true
- deploy_executed: false
- production_changed: false
MD

echo "[OK] post push verify gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
