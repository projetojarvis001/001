#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RESULT_FILE="dispatcher/jobs_results.json"
RAW_FILE="runtime/dispatcher/phase116_mesh_dispatcher_probe_${TS}.txt"
OUT_JSON="logs/executive/phase116_mesh_dispatcher_probe_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_probe_${TS}.md"

mkdir -p runtime/dispatcher logs/executive docs/generated

VISION_OK="$(jq -r '.results[] | select(.node=="vision") | .ok' "${RESULT_FILE}")"
FRIDAY_OK="$(jq -r '.results[] | select(.node=="friday") | .ok' "${RESULT_FILE}")"
TADASH_OK="$(jq -r '.results[] | select(.node=="tadash") | .ok' "${RESULT_FILE}")"

READY_COUNT=0
[ "${VISION_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true
[ "${FRIDAY_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true
[ "${TADASH_OK}" = "true" ] && READY_COUNT=$((READY_COUNT+1)) || true

OVERALL_OK=false
[ "${READY_COUNT}" -eq 3 ] && OVERALL_OK=true || true

{
  echo "===== PROBE PHASE116 ====="
  echo "VISION_OK=${VISION_OK}"
  echo "FRIDAY_OK=${FRIDAY_OK}"
  echo "TADASH_OK=${TADASH_OK}"
  echo "READY_COUNT=${READY_COUNT}"
  echo "OVERALL_OK=${OVERALL_OK}"
} | tee "${RAW_FILE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_dispatcher_probe: {
      raw_file: $raw_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      tadash_ok: $tadash_ok,
      ready_count: $ready_count,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 116 — Mesh Dispatcher Probe

## Probe
- raw_file: ${RAW_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- tadash_ok: ${TADASH_OK}
- ready_count: ${READY_COUNT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase116 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
