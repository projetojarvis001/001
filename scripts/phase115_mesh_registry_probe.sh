#!/usr/bin/env bash
set -euo pipefail

source ./scripts/load_mesh_env.sh >/dev/null

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RAW_FILE="runtime/registry/phase115_mesh_registry_probe_${TS}.txt"
OUT_JSON="logs/executive/phase115_mesh_registry_probe_${TS}.json"
OUT_MD="docs/generated/phase115_mesh_registry_probe_${TS}.md"

mkdir -p runtime/registry logs/executive docs/generated

VISION_HTTP_OK=false
FRIDAY_HTTP_OK=false
TADASH_HTTP_OK=false
VISION_ID_OK=false
FRIDAY_ID_OK=false
TADASH_ID_OK=false

exec > >(tee "${RAW_FILE}") 2>&1

echo "===== PROBE PHASE115 ====="
echo
echo "VISION -> http://${VISION_HOST}:${VISION_HTTP_PORT}/health"
if curl -fsS "http://${VISION_HOST}:${VISION_HTTP_PORT}/health"; then
  echo
  VISION_HTTP_OK=true
fi

echo
echo "FRIDAY -> http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}/health"
if curl -fsS "http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}/health"; then
  echo
  FRIDAY_HTTP_OK=true
fi

echo
echo "TADASH -> http://${TADASH_HOST}:${TADASH_HTTP_PORT}"
if curl -fsS "http://${TADASH_HOST}:${TADASH_HTTP_PORT}" >/dev/null; then
  echo "TADASH_HTTP_OK=true"
  TADASH_HTTP_OK=true
fi

echo
echo "===== REMOTE IDENTITY FILES ====="
echo "--- VISION ---"
if sshpass -p "${VISION_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${VISION_SSH_PORT}" "${VISION_SSH_USER}@${VISION_HOST}" "cat ~/mesh_registry/node_identity.json"; then
  VISION_ID_OK=true
fi

echo "--- FRIDAY ---"
if sshpass -p "${FRIDAY_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}@${FRIDAY_HOST}" "cat ~/mesh_registry/node_identity.json"; then
  FRIDAY_ID_OK=true
fi

echo "--- TADASH ---"
if sshpass -p "${TADASH_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}@${TADASH_HOST}" "cat ~/mesh_registry/node_identity.json"; then
  TADASH_ID_OK=true
fi

READY_COUNT=0
[ "${VISION_HTTP_OK}" = "true" ] && [ "${VISION_ID_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true
[ "${FRIDAY_HTTP_OK}" = "true" ] && [ "${FRIDAY_ID_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true
[ "${TADASH_HTTP_OK}" = "true" ] && [ "${TADASH_ID_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true

OVERALL_OK=false
[ "${READY_COUNT}" -eq 3 ] && OVERALL_OK=true || true

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --argjson vision_http_ok "${VISION_HTTP_OK}" \
  --argjson friday_http_ok "${FRIDAY_HTTP_OK}" \
  --argjson tadash_http_ok "${TADASH_HTTP_OK}" \
  --argjson vision_id_ok "${VISION_ID_OK}" \
  --argjson friday_id_ok "${FRIDAY_ID_OK}" \
  --argjson tadash_id_ok "${TADASH_ID_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_registry_probe: {
      raw_file: $raw_file,
      vision_http_ok: $vision_http_ok,
      friday_http_ok: $friday_http_ok,
      tadash_http_ok: $tadash_http_ok,
      vision_id_ok: $vision_id_ok,
      friday_id_ok: $friday_id_ok,
      tadash_id_ok: $tadash_id_ok,
      ready_count: $ready_count,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 115 — Mesh Registry Probe

## Probe
- raw_file: ${RAW_FILE}
- vision_http_ok: ${VISION_HTTP_OK}
- friday_http_ok: ${FRIDAY_HTTP_OK}
- tadash_http_ok: ${TADASH_HTTP_OK}
- vision_id_ok: ${VISION_ID_OK}
- friday_id_ok: ${FRIDAY_ID_OK}
- tadash_id_ok: ${TADASH_ID_OK}
- ready_count: ${READY_COUNT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo
echo "[OK] phase115 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
