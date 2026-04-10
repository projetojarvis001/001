#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase62_devops_readiness_${TS}.json"
OUT_MD="docs/generated/phase62_devops_readiness_${TS}.md"

REPO_OK=false
GIT_REMOTE_OK=false
BRANCH_NAME=""
LAST_COMMIT=""
LAST_COMMIT_SHORT=""
SSH_DIR_EXISTS=false
SSH_KEY_COUNT=0
DOCKER_BIN_OK=false
DOCKER_DAEMON_OK=false
ORBSTACK_OK=false
DOCKER_PS_OK=false
SHELL_WRITE_OK=false
SANDBOX_FILE="runtime/phase62_devops_probe.txt"

mkdir -p runtime

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_OK=true
fi

BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
LAST_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
LAST_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || true)"

if git remote get-url origin >/dev/null 2>&1; then
  GIT_REMOTE_OK=true
fi

if [ -d "${HOME}/.ssh" ]; then
  SSH_DIR_EXISTS=true
  SSH_KEY_COUNT="$(find "${HOME}/.ssh" -maxdepth 1 -type f \( -name 'id_*' -o -name '*.pem' \) | wc -l | tr -d ' ')"
fi

if command -v docker >/dev/null 2>&1; then
  DOCKER_BIN_OK=true
fi

if docker info >/dev/null 2>&1; then
  DOCKER_DAEMON_OK=true
fi

if ps aux | grep -i '[o]rbstack' >/dev/null 2>&1; then
  ORBSTACK_OK=true
fi

if docker ps >/dev/null 2>&1; then
  DOCKER_PS_OK=true
fi

echo "phase62_devops_probe_ok" > "${SANDBOX_FILE}"
if grep -q "phase62_devops_probe_ok" "${SANDBOX_FILE}" 2>/dev/null; then
  SHELL_WRITE_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg branch_name "${BRANCH_NAME}" \
  --arg last_commit "${LAST_COMMIT}" \
  --arg last_commit_short "${LAST_COMMIT_SHORT}" \
  --argjson repo_ok "${REPO_OK}" \
  --argjson git_remote_ok "${GIT_REMOTE_OK}" \
  --argjson ssh_dir_exists "${SSH_DIR_EXISTS}" \
  --argjson ssh_key_count "${SSH_KEY_COUNT}" \
  --argjson docker_bin_ok "${DOCKER_BIN_OK}" \
  --argjson docker_daemon_ok "${DOCKER_DAEMON_OK}" \
  --argjson orbstack_ok "${ORBSTACK_OK}" \
  --argjson docker_ps_ok "${DOCKER_PS_OK}" \
  --argjson shell_write_ok "${SHELL_WRITE_OK}" \
  '{
    created_at: $created_at,
    git: {
      repo_ok: $repo_ok,
      git_remote_ok: $git_remote_ok,
      branch_name: $branch_name,
      last_commit: $last_commit,
      last_commit_short: $last_commit_short
    },
    ssh: {
      ssh_dir_exists: $ssh_dir_exists,
      ssh_key_count: $ssh_key_count
    },
    container_runtime: {
      docker_bin_ok: $docker_bin_ok,
      docker_daemon_ok: $docker_daemon_ok,
      orbstack_ok: $orbstack_ok,
      docker_ps_ok: $docker_ps_ok
    },
    shell: {
      shell_write_ok: $shell_write_ok
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 62 — DevOps Readiness

## Git
- repo_ok: ${REPO_OK}
- git_remote_ok: ${GIT_REMOTE_OK}
- branch_name: ${BRANCH_NAME}
- last_commit_short: ${LAST_COMMIT_SHORT}

## SSH
- ssh_dir_exists: ${SSH_DIR_EXISTS}
- ssh_key_count: ${SSH_KEY_COUNT}

## Container runtime
- docker_bin_ok: ${DOCKER_BIN_OK}
- docker_daemon_ok: ${DOCKER_DAEMON_OK}
- orbstack_ok: ${ORBSTACK_OK}
- docker_ps_ok: ${DOCKER_PS_OK}

## Shell
- shell_write_ok: ${SHELL_WRITE_OK}
MD

echo "[OK] devops readiness gerado em ${OUT_JSON}"
echo "[OK] markdown readiness gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
