#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H:%M:%S)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_evidence_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_evidence_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

SEED_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_seed_*.json' | sort | tail -n 1)"
APPLY_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_apply_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_probe_*.json' | sort | tail -n 1)"
BUILD_FILE="$(find logs/executive -maxdepth 1 -name 'phase114_mesh_http_bootstrap_build_*.json' | sort | tail -n 1)"

APPLY_OK="$(jq -r '.mesh_http_bootstrap_apply.overall_ok' "${APPLY_FILE}")"
PROBE_OK="$(jq -r '.mesh_http_bootstrap_probe.overall_ok' "${PROBE_FILE}")"
BUILD_OK="$(jq -r '.mesh_http_bootstrap_build.overall_ok' "${BUILD_FILE}")"

FLOW_OK=false
if [ "${APPLY_OK}" = "true" ] && [ "${PROBE_OK}" = "true" ] && [ "${BUILD_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg seed_file "$SEED_FILE" \
  --arg apply_file "$APPLY_FILE" \
  --arg probe_file "$PROBE_FILE" \
  --arg build_file "$BUILD_FILE" \
  --argjson apply_ok "${APPLY_OK}" \
  --argjson probe_ok "${PROBE_OK}" \
  --argjson build_ok "${BUILD_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    mesh_http_bootstrap_flow: {
      seed_file: $seed_file,
      apply_file: $apply_file,
      probe_file: $probe_file,
      build_file: $build_file,
      apply_ok: $apply_ok,
      probe_ok: $probe_ok,
      build_ok: $build_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 114 — Mesh HTTP Bootstrap Evidence

## Flow
- apply_ok: ${APPLY_OK}
- probe_ok: ${PROBE_OK}
- build_ok: ${BUILD_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase114 evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
