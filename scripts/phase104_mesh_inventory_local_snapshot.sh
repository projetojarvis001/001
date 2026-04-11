#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/inventory/phase104_local_snapshot_${TS}.txt"
OUT_JSON="logs/executive/phase104_mesh_inventory_local_snapshot_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_local_snapshot_${TS}.md"

{
  echo "===== HOSTNAME ====="
  hostname || true
  echo

  echo "===== LOCAL IPS ====="
  ifconfig | sed -n '1,220p' || true
  echo

  echo "===== LISTEN PORTS ====="
  lsof -nP -iTCP -sTCP:LISTEN | sed -n '1,220p' || true
  echo

  echo "===== DOCKER PS ====="
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true
  echo

  echo "===== CRITICAL LOCAL URLS ====="
  curl -sS http://127.0.0.1:3000 >/dev/null && echo "jarvis_core_http=true" || echo "jarvis_core_http=false"
  curl -sS http://127.0.0.1:3001/login >/dev/null && echo "jarvis_grafana_http=true" || echo "jarvis_grafana_http=false"
  curl -sS http://127.0.0.1:5678 >/dev/null && echo "jarvis_n8n_http=true" || echo "jarvis_n8n_http=false"
  curl -sS http://127.0.0.1:9090/-/ready >/dev/null && echo "obs_prometheus_http=true" || echo "obs_prometheus_http=false"
  curl -sS http://127.0.0.1:3300/login >/dev/null && echo "obs_grafana_http=true" || echo "obs_grafana_http=false"
  curl -sS http://127.0.0.1:3100/ready >/dev/null && echo "obs_loki_http=true" || echo "obs_loki_http=false"
  curl -sS http://127.0.0.1:9100/metrics >/dev/null && echo "obs_node_exporter_http=true" || echo "obs_node_exporter_http=false"
  curl -sS http://127.0.0.1:8080/containers/ >/dev/null && echo "obs_cadvisor_http=true" || echo "obs_cadvisor_http=false"
  curl -sS http://127.0.0.1:9115 >/dev/null && echo "obs_blackbox_http=true" || echo "obs_blackbox_http=false"
} > "${RAW_FILE}" 2>&1

HOST_OK=false
DOCKER_OK=false
PORTS_OK=false

grep -q "===== HOSTNAME =====" "${RAW_FILE}" && HOST_OK=true || true
grep -q "jarvis-jarvis-core-1" "${RAW_FILE}" && DOCKER_OK=true || true
grep -q "LISTEN" "${RAW_FILE}" && PORTS_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson host_ok "${HOST_OK}" \
  --argjson docker_ok "${DOCKER_OK}" \
  --argjson ports_ok "${PORTS_OK}" \
  '{
    created_at: $created_at,
    local_snapshot: {
      raw_file: $raw_file,
      host_ok: $host_ok,
      docker_ok: $docker_ok,
      ports_ok: $ports_ok,
      overall_ok: ($host_ok and $docker_ok and $ports_ok)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 104 — Mesh Inventory Local Snapshot

## Snapshot
- raw_file: ${RAW_FILE}
- host_ok: ${HOST_OK}
- docker_ok: ${DOCKER_OK}
- ports_ok: ${PORTS_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 local snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
