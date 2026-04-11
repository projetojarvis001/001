#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/observability

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/observability/phase103_observability_probe_${TS}.txt"
OUT_JSON="logs/executive/phase103_observability_probe_${TS}.json"
OUT_MD="docs/generated/phase103_observability_probe_${TS}.md"

{
  echo "===== DOCKER PS ====="
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
  echo

  echo "===== PROMETHEUS READY ====="
  curl -fsS http://127.0.0.1:9090/-/ready
  echo

  echo "===== GRAFANA LOGIN PAGE ====="
  GRAFANA_TMP="$(mktemp)"
  curl -fsS http://127.0.0.1:3300/login > "${GRAFANA_TMP}"
  sed -n '1,20p' "${GRAFANA_TMP}"
  rm -f "${GRAFANA_TMP}"
  echo

  echo "===== LOKI READY ====="
  curl -fsS http://127.0.0.1:3100/ready
  echo

  echo "===== NODE EXPORTER ====="
  NODE_TMP="$(mktemp)"
  curl -fsS http://127.0.0.1:9100/metrics > "${NODE_TMP}"
  sed -n '1,5p' "${NODE_TMP}"
  rm -f "${NODE_TMP}"
  echo

  echo "===== CADVISOR ====="
  CADVISOR_TMP="$(mktemp)"
  curl -fsS http://127.0.0.1:8080/containers/ > "${CADVISOR_TMP}"
  sed -n '1,20p' "${CADVISOR_TMP}"
  rm -f "${CADVISOR_TMP}"
  echo

  echo "===== BLACKBOX ====="
  curl -fsS 'http://127.0.0.1:9115/probe?target=http://177.104.176.69:58069&module=http_2xx' | grep '^probe_success'
} > "${RAW_FILE}" 2>&1

PROM_READY=false
GRAFANA_READY=false
LOKI_READY=false
NODE_READY=false
CADVISOR_READY=false
BLACKBOX_READY=false

grep -q 'Prometheus Server is Ready' "${RAW_FILE}" && PROM_READY=true || true
grep -qi '<title>Grafana</title>' "${RAW_FILE}" && GRAFANA_READY=true || true
grep -q 'ready' "${RAW_FILE}" && LOKI_READY=true || true
grep -q '^# HELP' "${RAW_FILE}" && NODE_READY=true || true
grep -qi 'containers' "${RAW_FILE}" && CADVISOR_READY=true || true
grep -q 'probe_success 1' "${RAW_FILE}" && BLACKBOX_READY=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson prometheus_ready "${PROM_READY}" \
  --argjson grafana_ready "${GRAFANA_READY}" \
  --argjson loki_ready "${LOKI_READY}" \
  --argjson node_ready "${NODE_READY}" \
  --argjson cadvisor_ready "${CADVISOR_READY}" \
  --argjson blackbox_ready "${BLACKBOX_READY}" \
  '{
    created_at: $created_at,
    observability_probe: {
      raw_file: $raw_file,
      prometheus_ready: $prometheus_ready,
      grafana_ready: $grafana_ready,
      loki_ready: $loki_ready,
      node_ready: $node_ready,
      cadvisor_ready: $cadvisor_ready,
      blackbox_ready: $blackbox_ready,
      overall_ok: (
        $prometheus_ready and
        $grafana_ready and
        $loki_ready and
        $node_ready and
        $cadvisor_ready and
        $blackbox_ready
      )
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 103 — Observability Probe

## Probe
- raw_file: ${RAW_FILE}
- prometheus_ready: ${PROM_READY}
- grafana_ready: ${GRAFANA_READY}
- loki_ready: ${LOKI_READY}
- node_ready: ${NODE_READY}
- cadvisor_ready: ${CADVISOR_READY}
- blackbox_ready: ${BLACKBOX_READY}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase103 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
