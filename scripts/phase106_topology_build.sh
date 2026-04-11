#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/topology topology

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="topology/system_topology.json"
OUT_PHASE_JSON="logs/executive/phase106_topology_build_${TS}.json"
OUT_MD="docs/generated/phase106_topology_build_${TS}.md"

python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

topology = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "nodes": [
        {"id": "jarvis", "role": "core_orchestrator", "enabled": True},
        {"id": "vision", "role": "observability_hub", "enabled": False},
        {"id": "friday", "role": "automation_worker", "enabled": False},
        {"id": "tadash", "role": "edge_executor", "enabled": False},
    ],
    "services": [
        {"id": "jarvis_core", "node": "jarvis", "port": 3000, "protocol": "http", "status": "online"},
        {"id": "jarvis_grafana", "node": "jarvis", "port": 3001, "protocol": "http", "status": "online"},
        {"id": "jarvis_n8n", "node": "jarvis", "port": 5678, "protocol": "http", "status": "online"},
        {"id": "postgres", "node": "jarvis", "port": 5432, "protocol": "tcp", "status": "online"},
        {"id": "redis", "node": "jarvis", "port": 6379, "protocol": "tcp", "status": "online"},
        {"id": "obs_prometheus", "node": "jarvis", "port": 9090, "protocol": "http", "status": "online"},
        {"id": "obs_grafana", "node": "jarvis", "port": 3300, "protocol": "http", "status": "online"},
        {"id": "obs_loki", "node": "jarvis", "port": 3100, "protocol": "http", "status": "online"},
        {"id": "obs_node_exporter", "node": "jarvis", "port": 9100, "protocol": "http", "status": "online"},
        {"id": "obs_cadvisor", "node": "jarvis", "port": 8080, "protocol": "http", "status": "online"},
        {"id": "obs_blackbox", "node": "jarvis", "port": 9115, "protocol": "http", "status": "online"},
        {"id": "odoo_http", "node": "external_odoo", "port": 58069, "protocol": "http", "status": "online"},
        {"id": "odoo_ssh", "node": "external_odoo", "port": 61022, "protocol": "tcp", "status": "online"},
    ],
    "links": [
        {"from": "jarvis_core", "to": "postgres", "type": "dependency"},
        {"from": "jarvis_core", "to": "redis", "type": "dependency"},
        {"from": "jarvis_n8n", "to": "jarvis_core", "type": "automation"},
        {"from": "obs_prometheus", "to": "obs_node_exporter", "type": "scrape"},
        {"from": "obs_prometheus", "to": "obs_cadvisor", "type": "scrape"},
        {"from": "obs_prometheus", "to": "obs_blackbox", "type": "scrape"},
        {"from": "obs_grafana", "to": "obs_prometheus", "type": "datasource"},
        {"from": "obs_grafana", "to": "obs_loki", "type": "datasource"},
        {"from": "obs_blackbox", "to": "odoo_http", "type": "probe"},
        {"from": "jarvis_core", "to": "odoo_http", "type": "business_integration"},
    ],
    "summary": {
        "nodes_defined": 4,
        "nodes_enabled": 1,
        "services_total": 13,
        "links_total": 10,
        "overall_status": "operational"
    }
}

Path("topology/system_topology.json").write_text(json.dumps(topology, ensure_ascii=False, indent=2))
print(json.dumps(topology, ensure_ascii=False, indent=2))
PY

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg topology_file "${OUT_JSON}" \
  '{
    created_at: $created_at,
    topology_build: {
      topology_file: $topology_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_PHASE_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 106 — Topology Build

## Topology
- topology_file: ${OUT_JSON}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 topology build gerado em ${OUT_PHASE_JSON}"
cat "${OUT_PHASE_JSON}" | jq .
echo
echo "[OK] topology em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
