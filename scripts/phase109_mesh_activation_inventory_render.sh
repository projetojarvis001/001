#!/usr/bin/env bash
set -euo pipefail

mkdir -p inventory runtime/control_plane logs/executive docs/generated

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase109_inventory_render_${TS}.txt"
OUT_JSON="logs/executive/phase109_mesh_activation_inventory_render_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_inventory_render_${TS}.md"
OUT_INV="inventory/nodes.resolved.yml"

cat > "${OUT_INV}" <<YML
nodes:
  - name: jarvis
    role: core_orchestrator
    host: 127.0.0.1
    ssh_port: 22
    enabled: true
    probe_http: "http://127.0.0.1:3000"

  - name: vision
    role: observability_hub
    host: "${VISION_HOST}"
    ssh_port: ${VISION_SSH_PORT}
    enabled: true
    probe_http: "http://${VISION_HOST}:${VISION_HTTP_PORT}"

  - name: friday
    role: automation_worker
    host: "${FRIDAY_HOST}"
    ssh_port: ${FRIDAY_SSH_PORT}
    enabled: true
    probe_http: "http://${FRIDAY_HOST}:${FRIDAY_HTTP_PORT}"

  - name: tadash
    role: edge_executor
    host: "${TADASH_HOST}"
    ssh_port: ${TADASH_SSH_PORT}
    enabled: true
    probe_http: "http://${TADASH_HOST}:${TADASH_HTTP_PORT}"
YML

sed -n '1,260p' "${OUT_INV}" > "${RAW_FILE}"

INV_OK=false
grep -q 'vision' "${RAW_FILE}" && INV_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg inventory_file "${OUT_INV}" \
  --argjson inventory_ok "${INV_OK}" \
  '{
    created_at: $created_at,
    inventory_render: {
      raw_file: $raw_file,
      inventory_file: $inventory_file,
      inventory_ok: $inventory_ok,
      overall_ok: $inventory_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 109 — Mesh Activation Inventory Render

## Inventory
- raw_file: ${RAW_FILE}
- inventory_file: ${OUT_INV}
- inventory_ok: ${INV_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 inventory render gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
