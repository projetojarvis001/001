#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/topology topology

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/topology/phase106_topology_snapshot_${TS}.txt"
OUT_JSON="logs/executive/phase106_topology_snapshot_${TS}.json"
OUT_MD="docs/generated/phase106_topology_snapshot_${TS}.md"

{
  echo "===== DOCKER PS ====="
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  echo

  echo "===== NETWORK SOCKETS ====="
  lsof -nP -iTCP -sTCP:LISTEN | sed -n '1,260p'
  echo

  echo "===== HTTP CHECKS ====="
  curl -sS http://127.0.0.1:3000 >/dev/null && echo "jarvis_core=true" || echo "jarvis_core=false"
  curl -sS http://127.0.0.1:3001/login >/dev/null && echo "jarvis_grafana=true" || echo "jarvis_grafana=false"
  curl -sS http://127.0.0.1:5678 >/dev/null && echo "jarvis_n8n=true" || echo "jarvis_n8n=false"
  curl -sS http://127.0.0.1:9090/-/ready >/dev/null && echo "obs_prometheus=true" || echo "obs_prometheus=false"
  curl -sS http://127.0.0.1:3300/login >/dev/null && echo "obs_grafana=true" || echo "obs_grafana=false"
  curl -sS http://127.0.0.1:3100/ready >/dev/null && echo "obs_loki=true" || echo "obs_loki=false"
  curl -sS http://127.0.0.1:9100/metrics >/dev/null && echo "obs_node_exporter=true" || echo "obs_node_exporter=false"
  curl -sS http://127.0.0.1:8080/containers/ >/dev/null && echo "obs_cadvisor=true" || echo "obs_cadvisor=false"
  curl -sS 'http://127.0.0.1:9115/probe?target=http://177.104.176.69:58069&module=http_2xx' | grep -q '^probe_success 1' && echo "obs_blackbox=true" || echo "obs_blackbox=false"
  curl -sS http://177.104.176.69:58069 >/dev/null && echo "odoo_http=true" || echo "odoo_http=false"
  echo

  echo "===== TCP CHECKS ====="
  nc -z 127.0.0.1 5432 >/dev/null 2>&1 && echo "postgres_tcp=true" || echo "postgres_tcp=false"
  nc -z 127.0.0.1 6379 >/dev/null 2>&1 && echo "redis_tcp=true" || echo "redis_tcp=false"
  nc -z 177.104.176.69 61022 >/dev/null 2>&1 && echo "odoo_ssh_tcp=true" || echo "odoo_ssh_tcp=false"
  nc -z 177.104.176.69 58069 >/dev/null 2>&1 && echo "odoo_http_tcp=true" || echo "odoo_http_tcp=false"
} > "${RAW_FILE}" 2>&1

RAW_OK=false
grep -q 'jarvis-jarvis-core-1' "${RAW_FILE}" && RAW_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson raw_ok "${RAW_OK}" \
  '{
    created_at: $created_at,
    topology_snapshot: {
      raw_file: $raw_file,
      raw_ok: $raw_ok,
      overall_ok: $raw_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 106 — Topology Snapshot

## Snapshot
- raw_file: ${RAW_FILE}
- raw_ok: ${RAW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
