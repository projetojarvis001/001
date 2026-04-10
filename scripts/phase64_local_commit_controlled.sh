#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase64_local_commit_${TS}.json"
OUT_MD="docs/generated/phase64_local_commit_${TS}.md"

TARGET_FILE="docs/generated/devops_agent_tracked_probe.md"
COMMIT_MSG="chore: registra probe rastreavel da fase 64 para devops agent"

git add "${TARGET_FILE}"
git commit -m "${COMMIT_MSG}" >/tmp/phase64_commit.out 2>&1

NEW_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
NEW_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
NEW_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"
PREV_COMMIT="$(git rev-parse HEAD~1 2>/dev/null || true)"
REVERT_CMD="git revert --no-edit ${NEW_COMMIT_SHORT}"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg target_file "${TARGET_FILE}" \
  --arg commit_message "${COMMIT_MSG}" \
  --arg new_commit "${NEW_COMMIT}" \
  --arg new_commit_short "${NEW_COMMIT_SHORT}" \
  --arg new_subject "${NEW_SUBJECT}" \
  --arg prev_commit "${PREV_COMMIT}" \
  --arg revert_cmd "${REVERT_CMD}" \
  '{
    created_at: $created_at,
    commit: {
      target_file: $target_file,
      commit_message: $commit_message,
      new_commit: $new_commit,
      new_commit_short: $new_commit_short,
      new_subject: $new_subject,
      previous_commit: $prev_commit,
      revert_cmd: $revert_cmd
    },
    governance: {
      commit_executed: true,
      push_executed: false,
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

echo "[OK] local commit controlado gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
