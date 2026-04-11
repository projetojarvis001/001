#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/dashboard dashboard

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/dashboard/phase105_executive_dashboard_snapshot_${TS}.txt"
OUT_JSON="logs/executive/phase105_executive_dashboard_snapshot_${TS}.json"
OUT_MD="docs/generated/phase105_executive_dashboard_snapshot_${TS}.md"

{
  echo "===== HOST ====="
  hostname || true
  echo

  echo "===== DOCKER PS ====="
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true
  echo

  echo "===== LISTEN PORTS ====="
  lsof -nP -iTCP -sTCP:LISTEN | sed -n '1,220p' || true
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

DOCKER_OK=false
HTTP_OK=false
TCP_OK=false

grep -q 'jarvis-jarvis-core-1' "${RAW_FILE}" && DOCKER_OK=true || true
grep -q 'jarvis_core=true' "${RAW_FILE}" && grep -q 'obs_prometheus=true' "${RAW_FILE}" && grep -q 'odoo_http=true' "${RAW_FILE}" && HTTP_OK=true || true
grep -q 'postgres_tcp=true' "${RAW_FILE}" && grep -q 'redis_tcp=true' "${RAW_FILE}" && TCP_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson docker_ok "${DOCKER_OK}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson tcp_ok "${TCP_OK}" \
  '{
    created_at: $created_at,
    dashboard_snapshot: {
      raw_file: $raw_file,
      docker_ok: $docker_ok,
      http_ok: $http_ok,
      tcp_ok: $tcp_ok,
      overall_ok: ($docker_ok and $http_ok and $tcp_ok)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 105 — Executive Dashboard Snapshot

## Snapshot
- raw_file: ${RAW_FILE}
- docker_ok: ${DOCKER_OK}
- http_ok: ${HTTP_OK}
- tcp_ok: ${TCP_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase105 snapshot gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
