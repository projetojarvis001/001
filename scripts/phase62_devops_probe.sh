#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase62_devops_probe_${TS}.json"
OUT_MD="docs/generated/phase62_devops_probe_${TS}.md"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
LAST_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
LAST_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"
LAST_COMMIT_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null || true)"
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"

DOCKER_VERSION="$(docker --version 2>/dev/null || true)"
DOCKER_PS_HEAD="$(docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null | head -n 10 || true)"

PROBE_FILE="runtime/phase62_hello_world_probe.txt"
echo "hello world phase62 $(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "${PROBE_FILE}"
PROBE_OK=false
grep -q 'hello world phase62' "${PROBE_FILE}" 2>/dev/null && PROBE_OK=true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch "${BRANCH}" \
  --arg last_commit "${LAST_COMMIT}" \
  --arg last_commit_short "${LAST_COMMIT_SHORT}" \
  --arg last_commit_subject "${LAST_COMMIT_SUBJECT}" \
  --arg remote_url "${REMOTE_URL}" \
  --arg docker_version "${DOCKER_VERSION}" \
  --arg docker_ps_head "${DOCKER_PS_HEAD}" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson probe_ok "${PROBE_OK}" \
  '{
    created_at: $created_at,
    git_probe: {
      branch: $branch,
      last_commit: $last_commit,
      last_commit_short: $last_commit_short,
      last_commit_subject: $last_commit_subject,
      remote_url: $remote_url
    },
    runtime_probe: {
      docker_version: $docker_version,
      docker_ps_head: $docker_ps_head
    },
    shell_probe: {
      probe_file: $probe_file,
      probe_ok: $probe_ok
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 62 — DevOps Probe

## Git probe
- branch: ${BRANCH}
- last_commit_short: ${LAST_COMMIT_SHORT}
- last_commit_subject: ${LAST_COMMIT_SUBJECT}

## Runtime probe
- docker_version: ${DOCKER_VERSION}

## Shell probe
- probe_file: ${PROBE_FILE}
- probe_ok: ${PROBE_OK}
MD

echo "[OK] devops probe gerado em ${OUT_JSON}"
echo "[OK] markdown do probe gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
