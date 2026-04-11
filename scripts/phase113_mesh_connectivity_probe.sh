#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p runtime/control_plane logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase113_mesh_connectivity_probe_${TS}.txt"
OUT_JSON="logs/executive/phase113_mesh_connectivity_probe_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_connectivity_probe_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

probe_node() {
  local NAME="$1"
  local HOST="$2"
  local PORT="$3"
  local USER="$4"
  local PASS="$5"
  local HTTP_PORT="$6"

  echo "===== NODE ${NAME} =====" >> "${RAW_FILE}"

  local DNS_OK=false
  local PING_OK=false
  local TCP_OK=false
  local SSH_OK=false
  local HTTP_OK=false

  if dscacheutil -q host -a name "${HOST}" >/dev/null 2>&1 || ping -c 1 -W 1000 "${HOST}" >/dev/null 2>&1; then
    DNS_OK=true
  fi

  if ping -c 1 -W 1000 "${HOST}" >/dev/null 2>&1; then
    PING_OK=true
  fi

  if nc -z -w 3 "${HOST}" "${PORT}" >/dev/null 2>&1; then
    TCP_OK=true
  fi

  if command -v sshpass >/dev/null 2>&1; then
    if sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "${PORT}" "${USER}@${HOST}" 'echo HEALTH_OK' >/tmp/phase113_ssh_"${NAME}".out 2>/tmp/phase113_ssh_"${NAME}".err; then
      SSH_OK=true
    fi
  fi

  if curl -fsS --max-time 5 "http://${HOST}:${HTTP_PORT}" >/tmp/phase113_http_"${NAME}".out 2>/dev/null; then
    HTTP_OK=true
  fi

  echo "DNS_OK=${DNS_OK}" >> "${RAW_FILE}"
  echo "PING_OK=${PING_OK}" >> "${RAW_FILE}"
  echo "TCP_OK=${TCP_OK}" >> "${RAW_FILE}"
  echo "SSH_OK=${SSH_OK}" >> "${RAW_FILE}"
  echo "HTTP_OK=${HTTP_OK}" >> "${RAW_FILE}"
  echo >> "${RAW_FILE}"

  printf '%s;%s;%s;%s;%s;%s\n' "${NAME}" "${DNS_OK}" "${PING_OK}" "${TCP_OK}" "${SSH_OK}" "${HTTP_OK}"
}

: > "${RAW_FILE}"

VISION_RESULT="$(probe_node "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}" "${VISION_HTTP_PORT}")"
FRIDAY_RESULT="$(probe_node "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}" "${FRIDAY_HTTP_PORT}")"
TADASH_RESULT="$(probe_node "tadash" "${TADASH_HOST}" "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}" "${TADASH_SSH_PASS}" "${TADASH_HTTP_PORT}")"

parse_field() {
  echo "$1" | cut -d';' -f"$2"
}

VISION_DNS="$(parse_field "${VISION_RESULT}" 2)"
VISION_PING="$(parse_field "${VISION_RESULT}" 3)"
VISION_TCP="$(parse_field "${VISION_RESULT}" 4)"
VISION_SSH="$(parse_field "${VISION_RESULT}" 5)"
VISION_HTTP="$(parse_field "${VISION_RESULT}" 6)"

FRIDAY_DNS="$(parse_field "${FRIDAY_RESULT}" 2)"
FRIDAY_PING="$(parse_field "${FRIDAY_RESULT}" 3)"
FRIDAY_TCP="$(parse_field "${FRIDAY_RESULT}" 4)"
FRIDAY_SSH="$(parse_field "${FRIDAY_RESULT}" 5)"
FRIDAY_HTTP="$(parse_field "${FRIDAY_RESULT}" 6)"

TADASH_DNS="$(parse_field "${TADASH_RESULT}" 2)"
TADASH_PING="$(parse_field "${TADASH_RESULT}" 3)"
TADASH_TCP="$(parse_field "${TADASH_RESULT}" 4)"
TADASH_SSH="$(parse_field "${TADASH_RESULT}" 5)"
TADASH_HTTP="$(parse_field "${TADASH_RESULT}" 6)"

READY_COUNT=0
for x in \
  "${VISION_DNS}:${VISION_TCP}:${VISION_SSH}" \
  "${FRIDAY_DNS}:${FRIDAY_TCP}:${FRIDAY_SSH}" \
  "${TADASH_DNS}:${TADASH_TCP}:${TADASH_SSH}"
do
  if [ "${x}" = "true:true:true" ]; then
    READY_COUNT=$((READY_COUNT+1))
  fi
done

OVERALL_OK=false
[ "${READY_COUNT}" -ge 1 ] && OVERALL_OK=true

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --argjson vision_dns_ok "${VISION_DNS}" \
  --argjson vision_ping_ok "${VISION_PING}" \
  --argjson vision_tcp_ok "${VISION_TCP}" \
  --argjson vision_ssh_ok "${VISION_SSH}" \
  --argjson vision_http_ok "${VISION_HTTP}" \
  --argjson friday_dns_ok "${FRIDAY_DNS}" \
  --argjson friday_ping_ok "${FRIDAY_PING}" \
  --argjson friday_tcp_ok "${FRIDAY_TCP}" \
  --argjson friday_ssh_ok "${FRIDAY_SSH}" \
  --argjson friday_http_ok "${FRIDAY_HTTP}" \
  --argjson tadash_dns_ok "${TADASH_DNS}" \
  --argjson tadash_ping_ok "${TADASH_PING}" \
  --argjson tadash_tcp_ok "${TADASH_TCP}" \
  --argjson tadash_ssh_ok "${TADASH_SSH}" \
  --argjson tadash_http_ok "${TADASH_HTTP}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    connectivity_probe: {
      raw_file: $raw_file,
      vision_dns_ok: $vision_dns_ok,
      vision_ping_ok: $vision_ping_ok,
      vision_tcp_ok: $vision_tcp_ok,
      vision_ssh_ok: $vision_ssh_ok,
      vision_http_ok: $vision_http_ok,
      friday_dns_ok: $friday_dns_ok,
      friday_ping_ok: $friday_ping_ok,
      friday_tcp_ok: $friday_tcp_ok,
      friday_ssh_ok: $friday_ssh_ok,
      friday_http_ok: $friday_http_ok,
      tadash_dns_ok: $tadash_dns_ok,
      tadash_ping_ok: $tadash_ping_ok,
      tadash_tcp_ok: $tadash_tcp_ok,
      tadash_ssh_ok: $tadash_ssh_ok,
      tadash_http_ok: $tadash_http_ok,
      ready_count: $ready_count,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 113 — Mesh Connectivity Probe

## Probe
- raw_file: ${RAW_FILE}
- ready_count: ${READY_COUNT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
