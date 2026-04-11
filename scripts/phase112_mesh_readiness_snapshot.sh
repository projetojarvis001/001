#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase112_mesh_readiness_snapshot_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_snapshot_${TS}.md"
RAW_FILE="runtime/readiness/phase112_mesh_readiness_snapshot_${TS}.txt"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

./scripts/load_mesh_env.sh > "${RAW_FILE}" 2>&1

ENV_FILE=".secrets/mesh_nodes.env"
ENV_EXISTS=false
[ -f "${ENV_FILE}" ] && ENV_EXISTS=true

PLACEHOLDER_COUNT="$(grep -E 'COLE_AQUI' "${ENV_FILE}" 2>/dev/null | wc -l | tr -d ' ')"
[ -z "${PLACEHOLDER_COUNT}" ] && PLACEHOLDER_COUNT=0

VISION_HOST_OK=false
FRIDAY_HOST_OK=false
TADASH_HOST_OK=false

grep -q '^export VISION_HOST=' "${ENV_FILE}" 2>/dev/null && VISION_HOST_OK=true
grep -q '^export FRIDAY_HOST=' "${ENV_FILE}" 2>/dev/null && FRIDAY_HOST_OK=true
grep -q '^export TADASH_HOST=' "${ENV_FILE}" 2>/dev/null && TADASH_HOST_OK=true

OVERALL_OK=false
if [ "${ENV_EXISTS}" = true ]; then
  OVERALL_OK=true
fi

jq -n \
  --arg created_at "${created_at}" \
  --arg raw_file "${RAW_FILE}" \
  --argjson env_exists "${ENV_EXISTS}" \
  --argjson placeholder_count "${PLACEHOLDER_COUNT}" \
  --argjson vision_host_ok "${VISION_HOST_OK}" \
  --argjson friday_host_ok "${FRIDAY_HOST_OK}" \
  --argjson tadash_host_ok "${TADASH_HOST_OK}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    readiness_snapshot: {
      raw_file: $raw_file,
      env_exists: $env_exists,
      placeholder_count: $placeholder_count,
      vision_host_ok: $vision_host_ok,
      friday_host_ok: $friday_host_ok,
      tadash_host_ok: $tadash_host_ok,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 112 — Mesh Readiness Snapshot

## Snapshot
- raw_file: ${RAW_FILE}
- env_exists: ${ENV_EXISTS}
- placeholder_count: ${PLACEHOLDER_COUNT}
- vision_host_ok: ${VISION_HOST_OK}
- friday_host_ok: ${FRIDAY_HOST_OK}
- tadash_host_ok: ${TADASH_HOST_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
