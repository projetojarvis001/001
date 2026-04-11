#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p logs/executive docs/generated runtime/control_plane

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase110_mesh_runtime_probe_${TS}.txt"
OUT_JSON="logs/executive/phase110_mesh_runtime_probe_${TS}.json"
OUT_MD="docs/generated/phase110_mesh_runtime_probe_${TS}.md"

probe_node() {
  local NODE_NAME="$1"
  local HOST="$2"
  local SSH_PORT="$3"
  local USER="$4"
  local PASS="$5"
  local HTTP_PORT="$6"

  echo "===== NODE ${NODE_NAME} ====="

  if ping -c 1 -W 1000 "${HOST}" >/dev/null 2>&1; then
    echo "PING=true"
  else
    echo "PING=false"
  fi

  if nc -z -w 3 "${HOST}" "${SSH_PORT}" >/dev/null 2>&1; then
    echo "TCP_SSH=true"
  else
    echo "TCP_SSH=false"
  fi

  if curl -fsS --max-time 5 "http://${HOST}:${HTTP_PORT}" >/dev/null 2>&1; then
    echo "HTTP=true"
  else
    echo "HTTP=false"
  fi

  if sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${SSH_PORT}" "${USER}@${HOST}" "~/jarvis_node/node_health.sh" >/tmp/phase110_"${NODE_NAME}".json 2>/dev/null; then
    echo "REMOTE_HEALTH=true"
    cat /tmp/phase110_"${NODE_NAME}".json
  else
    echo "REMOTE_HEALTH=false"
  fi

  echo
}

{
  probe_node "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}" "${VISION_HTTP_PORT}"
  probe_node "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}" "${FRIDAY_HTTP_PORT}"
  probe_node "tadash" "${TADASH_HOST}" "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}" "${TADASH_SSH_PASS}" "${TADASH_HTTP_PORT}"
} > "${RAW_FILE}" 2>&1

PING_OK="$(grep -c '^PING=true' "${RAW_FILE}" || true)"
TCP_OK="$(grep -c '^TCP_SSH=true' "${RAW_FILE}" || true)"
HTTP_OK="$(grep -c '^HTTP=true' "${RAW_FILE}" || true)"
REMOTE_OK="$(grep -c '^REMOTE_HEALTH=true' "${RAW_FILE}" || true)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson ping_ok "${PING_OK}" \
  --argjson tcp_ok "${TCP_OK}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson remote_ok "${REMOTE_OK}" \
  '{
    created_at: $created_at,
    mesh_runtime_probe: {
      raw_file: $raw_file,
      ping_ok: $ping_ok,
      tcp_ok: $tcp_ok,
      http_ok: $http_ok,
      remote_ok: $remote_ok,
      overall_ok: ($remote_ok >= 3)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 110 — Mesh Runtime Probe

## Probe
- raw_file: ${RAW_FILE}
- ping_ok: ${PING_OK}
- tcp_ok: ${TCP_OK}
- http_ok: ${HTTP_OK}
- remote_ok: ${REMOTE_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase110 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
