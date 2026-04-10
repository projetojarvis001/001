#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase64_tracked_diff_${TS}.json"
OUT_MD="docs/generated/phase64_tracked_diff_${TS}.md"
PATCH_FILE="logs/executive/phase64_tracked_diff_${TS}.patch"
TARGET_FILE="docs/generated/devops_agent_tracked_probe.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
LAST_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
LAST_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
LAST_COMMIT_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"

git diff -- "${TARGET_FILE}" > "${PATCH_FILE}" || true
PATCH_SHA="$(shasum -a 256 "${PATCH_FILE}" | awk '{print $1}')"
PATCH_LINES="$(wc -l < "${PATCH_FILE}" | tr -d ' ')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg last_commit "${LAST_COMMIT}" \
  --arg last_commit_short "${LAST_COMMIT_SHORT}" \
  --arg last_commit_subject "${LAST_COMMIT_SUBJECT}" \
  --arg target_file "${TARGET_FILE}" \
  --arg patch_file "${PATCH_FILE}" \
  --arg patch_sha256 "${PATCH_SHA}" \
  --argjson patch_lines "${PATCH_LINES}" \
  '{
    created_at: $created_at,
    repo: {
      branch: $branch,
      last_commit: $last_commit,
      last_commit_short: $last_commit_short,
      last_commit_subject: $last_commit_subject
    },
    diff: {
      target_file: $target_file,
      patch_file: $patch_file,
      patch_sha256: $patch_sha256,
      patch_lines: $patch_lines
    },
    governance: {
      commit_executed: false,
      push_executed: false,
      deploy_executed: false
    }
  }' > "${OUT_JSON}"

echo "[OK] tracked diff gerado em ${OUT_JSON}"
echo "[OK] patch gerado em ${PATCH_FILE}"
cat "${OUT_JSON}" | jq .
