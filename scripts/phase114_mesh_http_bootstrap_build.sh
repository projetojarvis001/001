#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated control_plane

TS="$(date +%Y%m%d-%H%M%S)"
OUT_STATE="control_plane/mesh_http_bootstrap_state.json"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_build_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_build_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_probe_*.json' | sort | tail -n 1)"

APPLY_OK="$(jq -r '.mesh_http_bootstrap_apply.overall_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.mesh_http_bootstrap_probe.overall_ok' "${PROBE_FILE}")"
READY_COUNT="$(jq -r '.mesh_http_bootstrap_probe.ready_count' "${PROBE_FILE}")"

STATUS="partial"
if [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ]; then
  STATUS="fully_operational"
elif [ "${APPLY_OK}" = "true" ]; then
  STATUS="http_bootstrapped_partial"
fi

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg apply_file "$APPLY_FILE" \
  --arg probe_file "$PROBE_FILE" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson ready_count "${READY_COUNT}" \
  --arg status "$STATUS" \
  '{
    created_at: $created_at,
    mesh_http_bootstrap_state: {
      apply_file: $apply_file,
      probe_file: $probe_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      ready_count: $ready_count,
      status: $status,
      overall_ok: true
    }
  }' > "${OUT_STATE}"

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg state_file "$OUT_STATE" \
  --arg status "$STATUS" \
  '{
    created_at: $created_at,
    mesh_http_bootstrap_build: {
      state_file: $state_file,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 114 — Mesh HTTP Bootstrap Build

## Build
- state_file: ${OUT_STATE}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase114 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
