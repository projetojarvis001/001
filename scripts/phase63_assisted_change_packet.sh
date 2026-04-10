#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase63_assisted_change_packet_${TS}.json"
OUT_MD="docs/generated/phase63_assisted_change_packet_${TS}.md"

CHANGE_FILE="$(ls -1t logs/executive/phase63_controlled_change_*.json 2>/dev/null | head -n 1 || true)"
DIFF_FILE_JSON="$(ls -1t logs/executive/phase63_repo_diff_*.json 2>/dev/null | head -n 1 || true)"
READINESS_FILE="$(ls -1t logs/executive/phase62_devops_readiness_*.json 2>/dev/null | head -n 1 || true)"

TARGET_FILE="$(jq -r '.change.target_file // ""' "${CHANGE_FILE}" 2>/dev/null || true)"
FILE_SHA="$(jq -r '.change.file_sha256 // ""' "${CHANGE_FILE}" 2>/dev/null || true)"
BRANCH="$(jq -r '.repo.branch // ""' "${DIFF_FILE_JSON}" 2>/dev/null || true)"
LAST_COMMIT_SHORT="$(jq -r '.repo.last_commit_short // ""' "${DIFF_FILE_JSON}" 2>/dev/null || true)"
STATUS_SHORT="$(jq -r '.repo.status_short // ""' "${DIFF_FILE_JSON}" 2>/dev/null || true)"
DOCKER_OK="$(jq -r '.container_runtime.docker_daemon_ok // false' "${READINESS_FILE}" 2>/dev/null || true)"
SHELL_OK="$(jq -r '.shell.shell_write_ok // false' "${READINESS_FILE}" 2>/dev/null || true)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg target_file "${TARGET_FILE}" \
  --arg file_sha "${FILE_SHA}" \
  --arg branch "${BRANCH}" \
  --arg last_commit_short "${LAST_COMMIT_SHORT}" \
  --arg status_short "${STATUS_SHORT}" \
  --argjson docker_ok "${DOCKER_OK}" \
  --argjson shell_ok "${SHELL_OK}" \
  --arg change_file "${CHANGE_FILE}" \
  --arg diff_file_json "${DIFF_FILE_JSON}" \
  --arg readiness_file "${READINESS_FILE}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_63_ASSISTED_CHANGE",
      target_file: $target_file,
      file_sha256: $file_sha,
      branch: $branch,
      last_commit_short: $last_commit_short,
      docker_ok: $docker_ok,
      shell_ok: $shell_ok
    },
    repo: {
      status_short: $status_short
    },
    governance: {
      deploy_executed: false,
      commit_executed: false,
      push_executed: false,
      production_changed: false
    },
    sources: {
      change_file: $change_file,
      diff_file_json: $diff_file_json,
      readiness_file: $readiness_file
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 63 — Assisted Change Packet

## Summary
- target_file: ${TARGET_FILE}
- file_sha256: ${FILE_SHA}
- branch: ${BRANCH}
- last_commit_short: ${LAST_COMMIT_SHORT}
- docker_ok: ${DOCKER_OK}
- shell_ok: ${SHELL_OK}

## Repo status
${STATUS_SHORT}

## Governança
- deploy_executed: false
- commit_executed: false
- push_executed: false
- production_changed: false
MD

echo "[OK] assisted change packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
