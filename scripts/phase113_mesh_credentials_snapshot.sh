#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p runtime/control_plane logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase113_mesh_credentials_snapshot_${TS}.txt"
OUT_JSON="logs/executive/phase113_mesh_credentials_snapshot_${TS}.json"
OUT_MD="docs/generated/phase113_mesh_credentials_snapshot_${TS}.md"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

./scripts/load_mesh_env.sh > "${RAW_FILE}"

PLACEHOLDER_COUNT="$(grep -Eci 'COLE_AQUI|IP_OU_HOST_REAL|USUARIO_REAL|SENHA_REAL' .secrets/mesh_nodes.env || true)"
ENV_EXISTS=false
[ -f .secrets/mesh_nodes.env ] && ENV_EXISTS=true

VISION_READY=false
FRIDAY_READY=false
TADASH_READY=false

grep -q '^export VISION_HOST=' .secrets/mesh_nodes.env && [ "${VISION_HOST:-}" != "" ] && [[ "${VISION_HOST:-}" != *COLE_AQUI* ]] && VISION_READY=true || true
grep -q '^export FRIDAY_HOST=' .secrets/mesh_nodes.env && [ "${FRIDAY_HOST:-}" != "" ] && [[ "${FRIDAY_HOST:-}" != *COLE_AQUI* ]] && FRIDAY_READY=true || true
grep -q '^export TADASH_HOST=' .secrets/mesh_nodes.env && [ "${TADASH_HOST:-}" != "" ] && [[ "${TADASH_HOST:-}" != *COLE_AQUI* ]] && TADASH_READY=true || true

OVERALL_OK=false
if [ "${ENV_EXISTS}" = true ] && [ "${PLACEHOLDER_COUNT}" = "0" ]; then
  OVERALL_OK=true
fi

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --argjson env_exists "${ENV_EXISTS}" \
  --argjson placeholder_count "${PLACEHOLDER_COUNT}" \
  --argjson vision_ready "${VISION_READY}" \
  --argjson friday_ready "${FRIDAY_READY}" \
  --argjson tadash_ready "${TADASH_READY}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    credentials_snapshot: {
      raw_file: $raw_file,
      env_exists: $env_exists,
      placeholder_count: $placeholder_count,
      vision_ready: $vision_ready,
      friday_ready: $friday_ready,
      tadash_ready: $tadash_ready,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 113 — Mesh Credentials Snapshot

## Snapshot
- raw_file: ${RAW_FILE}
- env_exists: ${ENV_EXISTS}
- placeholder_count: ${PLACEHOLDER_COUNT}
- vision_ready: ${VISION_READY}
- friday_ready: ${FRIDAY_READY}
- tadash_ready: ${TADASH_READY}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase113 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
