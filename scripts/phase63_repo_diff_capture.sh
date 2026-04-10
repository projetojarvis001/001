#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase63_repo_diff_${TS}.json"
OUT_MD="docs/generated/phase63_repo_diff_${TS}.md"
DIFF_FILE="logs/executive/phase63_repo_diff_${TS}.patch"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
LAST_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
LAST_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
LAST_COMMIT_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"
STATUS_SHORT="$(git status --short 2>/dev/null || true)"

git diff -- runtime/devops_agent_controlled_change.log > "${DIFF_FILE}" || true

PATCH_SHA=""
[ -f "${DIFF_FILE}" ] && PATCH_SHA="$(shasum -a 256 "${DIFF_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg last_commit "${LAST_COMMIT}" \
  --arg last_commit_short "${LAST_COMMIT_SHORT}" \
  --arg last_commit_subject "${LAST_COMMIT_SUBJECT}" \
  --arg status_short "${STATUS_SHORT}" \
  --arg diff_file "${DIFF_FILE}" \
  --arg patch_sha256 "${PATCH_SHA}" \
  '{
    created_at: $created_at,
    repo: {
      branch: $branch,
      last_commit: $last_commit,
      last_commit_short: $last_commit_short,
      last_commit_subject: $last_commit_subject,
      status_short: $status_short
    },
    diff: {
      diff_file: $diff_file,
      patch_sha256: $patch_sha256
    },
    governance: {
      commit_executed: false,
      push_executed: false,
      deploy_executed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 63 — Repo Diff Capture

## Repo
- branch: ${BRANCH}
- last_commit_short: ${LAST_COMMIT_SHORT}
- last_commit_subject: ${LAST_COMMIT_SUBJECT}

## Status
${STATUS_SHORT}

## Diff
- diff_file: ${DIFF_FILE}
- patch_sha256: ${PATCH_SHA}

## Governança
- commit_executed: false
- push_executed: false
- deploy_executed: false
MD

echo "[OK] repo diff gerado em ${OUT_JSON}"
echo "[OK] markdown do repo diff gerado em ${OUT_MD}"
echo "[OK] patch gerado em ${DIFF_FILE}"
cat "${OUT_JSON}" | jq .
