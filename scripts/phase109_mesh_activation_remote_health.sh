#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/control_plane logs/executive docs/generated

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase109_remote_health_${TS}.txt"
OUT_JSON="logs/executive/phase109_mesh_activation_remote_health_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_remote_health_${TS}.md"

: > "${RAW_FILE}"

run_probe() {
  local name="$1"
  local host="$2"
  local port="$3"
  local user="$4"
  local pass="$5"

  {
    echo "===== NODE ${name} ====="
    sshpass -p "${pass}" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "${port}" "${user}@${host}" \
      "hostname; uptime; printf '\n'; docker ps --format 'table {{.Names}}\t{{.Status}}' || true"
    echo
  } >> "${RAW_FILE}" 2>&1 || true
}

run_probe "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}"
run_probe "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}"
run_probe "tadash" "${TADASH_HOST}" "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}" "${TADASH_SSH_PASS}"

VISION_OK=false
FRIDAY_OK=false
TADASH_OK=false

grep -q '===== NODE vision =====' "${RAW_FILE}" && grep -A3 '===== NODE vision =====' "${RAW_FILE}" | grep -qv 'Permission denied' && VISION_OK=true || true
grep -q '===== NODE friday =====' "${RAW_FILE}" && grep -A3 '===== NODE friday =====' "${RAW_FILE}" | grep -qv 'Permission denied' && FRIDAY_OK=true || true
grep -q '===== NODE tadash =====' "${RAW_FILE}" && grep -A3 '===== NODE tadash =====' "${RAW_FILE}" | grep -qv 'Permission denied' && TADASH_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  '{
    created_at: $created_at,
    remote_health: {
      raw_file: $raw_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      tadash_ok: $tadash_ok,
      overall_ok: ($vision_ok or $friday_ok or $tadash_ok)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 109 — Mesh Activation Remote Health

## Remote Health
- raw_file: ${RAW_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- tadash_ok: ${TADASH_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 remote health gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
