#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/observability

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/observability/phase103_observability_apply_${TS}.txt"
OUT_JSON="logs/executive/phase103_observability_apply_${TS}.json"
OUT_MD="docs/generated/phase103_observability_apply_${TS}.md"

cd observability || exit 1

docker compose up -d > "../${RAW_FILE}" 2>&1

cd .. || exit 1

PROM_OK=false
GRAFANA_OK=false
LOKI_OK=false
NODE_OK=false
CADVISOR_OK=false
BLACKBOX_OK=false

docker ps --format '{{.Names}}' | grep -q '^obs_prometheus$' && PROM_OK=true || true
docker ps --format '{{.Names}}' | grep -q '^obs_grafana$' && GRAFANA_OK=true || true
docker ps --format '{{.Names}}' | grep -q '^obs_loki$' && LOKI_OK=true || true
docker ps --format '{{.Names}}' | grep -q '^obs_node_exporter$' && NODE_OK=true || true
docker ps --format '{{.Names}}' | grep -q '^obs_cadvisor$' && CADVISOR_OK=true || true
docker ps --format '{{.Names}}' | grep -q '^obs_blackbox$' && BLACKBOX_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson prometheus_ok "${PROM_OK}" \
  --argjson grafana_ok "${GRAFANA_OK}" \
  --argjson loki_ok "${LOKI_OK}" \
  --argjson node_exporter_ok "${NODE_OK}" \
  --argjson cadvisor_ok "${CADVISOR_OK}" \
  --argjson blackbox_ok "${BLACKBOX_OK}" \
  '{
    created_at: $created_at,
    observability_apply: {
      raw_file: $raw_file,
      prometheus_ok: $prometheus_ok,
      grafana_ok: $grafana_ok,
      loki_ok: $loki_ok,
      node_exporter_ok: $node_exporter_ok,
      cadvisor_ok: $cadvisor_ok,
      blackbox_ok: $blackbox_ok,
      overall_ok: (
        $prometheus_ok and
        $grafana_ok and
        $loki_ok and
        $node_exporter_ok and
        $cadvisor_ok and
        $blackbox_ok
      )
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 103 — Observability Apply

## Apply
- raw_file: ${RAW_FILE}
- prometheus_ok: ${PROM_OK}
- grafana_ok: ${GRAFANA_OK}
- loki_ok: ${LOKI_OK}
- node_exporter_ok: ${NODE_OK}
- cadvisor_ok: ${CADVISOR_OK}
- blackbox_ok: ${BLACKBOX_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase103 apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
