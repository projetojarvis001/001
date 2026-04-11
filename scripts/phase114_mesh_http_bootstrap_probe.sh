#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

mkdir -p logs/executive docs/generated runtime/control_plane
TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase114_mesh_http_bootstrap_probe_${TS}.txt"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_probe_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_probe_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

exec > >(tee "${RAW_FILE}") 2>&1

probe_http() {
  local URL="$1"
  curl -fsS --max-time 8 "$URL" >/dev/null 2>&1
}

VISION_HTTP_OK=false
FRIDAY_HTTP_OK=false
TADASH_HTTP_OK=false

echo "===== HTTP PROBE PHASE114 ====="

echo "VISION -> http://${VISION_HOST}:${VISION_HTTP_PORT}/health"
if probe_http "http://${VISION_HOST}:${VISION_HTTP_PORT}/health"; then
  VISION_HTTP_OK=true
fi
echo "VISION_HTTP_OK=${VISION_HTTP_OK}"

echo
echo "FRIDAY -> http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}/health"
if probe_http "http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}/health"; then
  FRIDAY_HTTP_OK=true
fi
echo "FRIDAY_HTTP_OK=${FRIDAY_HTTP_OK}"

echo
echo "TADASH -> http://${TADASH_HOST}:${TADASH_HTTP_PORT}"
if probe_http "http://${TADASH_HOST}:${TADASH_HTTP_PORT}"; then
  TADASH_HTTP_OK=true
fi
echo "TADASH_HTTP_OK=${TADASH_HTTP_OK}"

READY_COUNT=0
[ "${VISION_HTTP_OK}" = true ] && READY_COUNT=$((READY_COUNT+1))
[ "${FRIDAY_HTTP_OK}" = true ] && READY_COUNT=$((READY_COUNT+1))
[ "${TADASH_HTTP_OK}" = true ] && READY_COUNT=$((READY_COUNT+1))

OVERALL_OK=false
if [ "${READY_COUNT}" -eq 3 ]; then
  OVERALL_OK=true
fi

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg raw_file "$RAW_FILE" \
  --argjson vision_http_ok "${VISION_HTTP_OK}" \
  --argjson friday_http_ok "${FRIDAY_HTTP_OK}" \
  --argjson tadash_http_ok "${TADASH_HTTP_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_http_bootstrap_probe: {
      raw_file: $raw_file,
      vision_http_ok: $vision_http_ok,
      friday_http_ok: $friday_http_ok,
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
# FASE 114 — Mesh HTTP Bootstrap Probe

## Probe
- raw_file: ${RAW_FILE}
- vision_http_ok: ${VISION_HTTP_OK}
- friday_http_ok: ${FRIDAY_HTTP_OK}
- tadash_http_ok: ${TADASH_HTTP_OK}
- ready_count: ${READY_COUNT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase114 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
