#!/usr/bin/env bash
set -euo pipefail

source ./scripts/load_mesh_env.sh >/dev/null

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RAW_FILE="runtime/registry/phase115_mesh_registry_apply_${TS}.txt"
OUT_JSON="logs/executive/phase115_mesh_registry_apply_${TS}.json"
OUT_MD="docs/generated/phase115_mesh_registry_apply_${TS}.md"
REGISTRY_FILE="registry/mesh_nodes_registry.json"

mkdir -p registry runtime/registry logs/executive docs/generated

cat > "${REGISTRY_FILE}" <<JSON
{
  "created_at": "${CREATED_AT}",
  "registry_version": 1,
  "nodes": [
    {
      "name": "jarvis",
      "role": "core_orchestrator",
      "host": "192.168.8.121",
      "ssh_port": 22,
      "health_url": "http://192.168.8.121:3000",
      "status": "online"
    },
    {
      "name": "vision",
      "role": "observability_hub",
      "host": "${VISION_HOST}",
      "ssh_port": ${VISION_SSH_PORT},
      "health_url": "http://${VISION_HOST}:${VISION_HTTP_PORT}/health",
      "status": "online"
    },
    {
      "name": "friday",
      "role": "automation_worker",
      "host": "${FRIDAY_HOST}",
      "ssh_port": ${FRIDAY_SSH_PORT},
      "health_url": "http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}/health",
      "status": "online"
    },
    {
      "name": "tadash",
      "role": "edge_executor",
      "host": "${TADASH_HOST}",
      "ssh_port": ${TADASH_SSH_PORT},
      "health_url": "http://${TADASH_HOST}:${TADASH_HTTP_PORT}",
      "status": "online"
    }
  ]
}
JSON

VISION_OK=false
FRIDAY_OK=false
TADASH_OK=false
REGISTRY_OK=false

{
  echo "===== APPLY PHASE115 ====="
  echo
  echo "===== REGISTRY FILE ====="
  cat "${REGISTRY_FILE}" | jq .

  echo
  echo "===== DEPLOY VISION HEARTBEAT ====="
  sshpass -p "${VISION_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${VISION_SSH_PORT}" "${VISION_SSH_USER}@${VISION_HOST}" "
    mkdir -p ~/mesh_registry &&
    cat > ~/mesh_registry/node_identity.json <<'JSON'
{
  \"name\": \"vision\",
  \"role\": \"observability_hub\",
  \"host\": \"${VISION_HOST}\",
  \"heartbeat\": \"${CREATED_AT}\",
  \"status\": \"online\"
}
JSON
    cat ~/mesh_registry/node_identity.json
  "

  echo
  echo "===== DEPLOY FRIDAY HEARTBEAT ====="
  sshpass -p "${FRIDAY_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}@${FRIDAY_HOST}" "
    mkdir -p ~/mesh_registry &&
    cat > ~/mesh_registry/node_identity.json <<'JSON'
{
  \"name\": \"friday\",
  \"role\": \"automation_worker\",
  \"host\": \"${FRIDAY_HOST}\",
  \"heartbeat\": \"${CREATED_AT}\",
  \"status\": \"online\"
}
JSON
    cat ~/mesh_registry/node_identity.json
  "

  echo
  echo "===== DEPLOY TADASH HEARTBEAT ====="
  sshpass -p "${TADASH_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}@${TADASH_HOST}" "
    mkdir -p ~/mesh_registry &&
    cat > ~/mesh_registry/node_identity.json <<'JSON'
{
  \"name\": \"tadash\",
  \"role\": \"edge_executor\",
  \"host\": \"${TADASH_HOST}\",
  \"heartbeat\": \"${CREATED_AT}\",
  \"status\": \"online\"
}
JSON
    cat ~/mesh_registry/node_identity.json
  "
} | tee "${RAW_FILE}"

grep -q '"name": "vision"' "${RAW_FILE}" && VISION_OK=true || true
grep -q '"name": "friday"' "${RAW_FILE}" && FRIDAY_OK=true || true
grep -q '"name": "tadash"' "${RAW_FILE}" && TADASH_OK=true || true
[ -f "${REGISTRY_FILE}" ] && REGISTRY_OK=true || true

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --arg registry_file "${REGISTRY_FILE}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  --argjson registry_ok "${REGISTRY_OK}" \
  '{
    created_at: $created_at,
    mesh_registry_apply: {
      raw_file: $raw_file,
      registry_file: $registry_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      tadash_ok: $tadash_ok,
      registry_ok: $registry_ok,
      overall_ok: ($vision_ok and $friday_ok and $tadash_ok and $registry_ok)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 115 — Mesh Registry Apply

## Apply
- raw_file: ${RAW_FILE}
- registry_file: ${REGISTRY_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- tadash_ok: ${TADASH_OK}
- registry_ok: ${REGISTRY_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase115 apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
