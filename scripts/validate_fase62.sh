#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 62 ====="

echo
echo "===== BUILD DEVOPS READINESS ====="
./scripts/phase62_devops_readiness.sh
READINESS_FILE="$(ls -1t logs/executive/phase62_devops_readiness_*.json 2>/dev/null | head -n 1 || true)"
echo "READINESS_FILE=${READINESS_FILE}"

echo
echo "===== BUILD ASSISTED CHANGE PLAN ====="
./scripts/phase62_assisted_change_plan.sh
PLAN_FILE="$(ls -1t logs/executive/phase62_assisted_change_plan_*.json 2>/dev/null | head -n 1 || true)"
echo "PLAN_FILE=${PLAN_FILE}"

echo
echo "===== BUILD DEVOPS PROBE ====="
./scripts/phase62_devops_probe.sh
PROBE_FILE="$(ls -1t logs/executive/phase62_devops_probe_*.json 2>/dev/null | head -n 1 || true)"
echo "PROBE_FILE=${PROBE_FILE}"

echo
echo "===== CHECK JSON ====="
jq -e '.git.repo_ok == true' "${READINESS_FILE}" >/dev/null
jq -e '.shell.shell_write_ok == true' "${READINESS_FILE}" >/dev/null
jq -e '.change_unit.deploy_real_now == false' "${PLAN_FILE}" >/dev/null
jq -e '.shell_probe.probe_ok == true' "${PROBE_FILE}" >/dev/null
jq -e '.git_probe.last_commit_short != ""' "${PROBE_FILE}" >/dev/null
echo "[OK] readiness, plano e probe consistentes"

echo
echo "===== CHECK DEVOPS BASE ====="
jq -e '.git.git_remote_ok == true or .git.git_remote_ok == false' "${READINESS_FILE}" >/dev/null
jq -e '.container_runtime.docker_bin_ok == true or .container_runtime.docker_bin_ok == false' "${READINESS_FILE}" >/dev/null
jq -e '.container_runtime.docker_daemon_ok == true or .container_runtime.docker_daemon_ok == false' "${READINESS_FILE}" >/dev/null
echo "[OK] base devops mapeada"

echo
echo "===== SANIDADE ====="
bash -n scripts/phase62_devops_readiness.sh
bash -n scripts/phase62_assisted_change_plan.sh
bash -n scripts/phase62_devops_probe.sh
bash -n scripts/validate_fase62.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 62 validada"
