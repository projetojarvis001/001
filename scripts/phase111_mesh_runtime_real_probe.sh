#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/control_plane

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase111_mesh_runtime_real_probe_${TS}.txt"
OUT_JSON="logs/executive/phase111_mesh_runtime_real_probe_${TS}.json"
OUT_MD="docs/generated/phase111_mesh_runtime_real_probe_${TS}.md"

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

probe_node() {
  local name="$1"
  local host="$2"
  local ssh_port="$3"
  local http_port="$4"
  local user="$5"
  local pass="$6"

  local ping_ok=false
  local tcp_ok=false
  local http_ok=false
  local remote_ok=false

  ping -c 1 -W 1 "${host}" >/dev/null 2>&1 && ping_ok=true || true
  nc -z -w 2 "${host}" "${ssh_port}" >/dev/null 2>&1 && tcp_ok=true || true
  curl -fsS --max-time 3 "http://${host}:${http_port}" >/dev/null 2>&1 && http_ok=true || true

  sshpass -p "${pass}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p "${ssh_port}" "${user}@${host}" '~/jarvis_node_runtime/healthcheck.sh' >/dev/null 2>&1 && remote_ok=true || true

  echo "===== NODE ${name} ====="
  echo "PING=${ping_ok}"
  echo "TCP_SSH=${tcp_ok}"
  echo "HTTP=${http_ok}"
  echo "REMOTE_HEALTH=${remote_ok}"
}

{
  probe_node "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_HTTP_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}"
  probe_node "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_HTTP_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}"
  probe_node "tadash" "${TADASH_HOST}" "${TADASH_SSH_PORT}" "${TADASH_HTTP_PORT}" "${TADASH_SSH_USER}" "${TADASH_SSH_PASS}"
} > "${RAW_FILE}"

PING_OK="$(grep -c 'PING=true' "${RAW_FILE}" || true)"
TCP_OK="$(grep -c 'TCP_SSH=true' "${RAW_FILE}" || true)"
HTTP_OK="$(grep -c 'HTTP=true' "${RAW_FILE}" || true)"
REMOTE_OK="$(grep -c 'REMOTE_HEALTH=true' "${RAW_FILE}" || true)"

OVERALL_OK=false
[ "${REMOTE_OK}" -ge 3 ] && OVERALL_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson ping_ok "${PING_OK}" \
  --argjson tcp_ok "${TCP_OK}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson remote_ok "${REMOTE_OK}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_runtime_real_probe: {
      raw_file: $raw_file,
      ping_ok: $ping_ok,
      tcp_ok: $tcp_ok,
      http_ok: $http_ok,
      remote_ok: $remote_ok,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 111 — Mesh Runtime Real Probe

## Probe
- raw_file: ${RAW_FILE}
- ping_ok: ${PING_OK}
- tcp_ok: ${TCP_OK}
- http_ok: ${HTTP_OK}
- remote_ok: ${REMOTE_OK}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase111 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
