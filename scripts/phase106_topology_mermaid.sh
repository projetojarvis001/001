#!/usr/bin/env bash
set -euo pipefail

mkdir -p topology docs/generated logs/executive runtime/topology

TS="$(date +%Y%m%d-%H%M%S)"
OUT_MMD="topology/system_topology.mmd"
OUT_JSON="logs/executive/phase106_topology_mermaid_${TS}.json"
OUT_MD="docs/generated/phase106_topology_mermaid_${TS}.md"

cat > "${OUT_MMD}" <<'MMD'
graph TD
    JARVIS_CORE[jarvis_core :3000]
    POSTGRES[postgres :5432]
    REDIS[redis :6379]
    N8N[jarvis_n8n :5678]
    JGRAFANA[jarvis_grafana :3001]

    PROM[obs_prometheus :9090]
    OGRAFANA[obs_grafana :3300]
    LOKI[obs_loki :3100]
    NODE[obs_node_exporter :9100]
    CADVISOR[obs_cadvisor :8080]
    BLACKBOX[obs_blackbox :9115]

    ODOOHTTP[odoo_http :58069]
    ODOOSSH[odoo_ssh :61022]

    JARVIS_CORE --> POSTGRES
    JARVIS_CORE --> REDIS
    N8N --> JARVIS_CORE
    PROM --> NODE
    PROM --> CADVISOR
    PROM --> BLACKBOX
    OGRAFANA --> PROM
    OGRAFANA --> LOKI
    BLACKBOX --> ODOOHTTP
    JARVIS_CORE --> ODOOHTTP
MMD

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg mermaid_file "${OUT_MMD}" \
  '{
    created_at: $created_at,
    topology_mermaid: {
      mermaid_file: $mermaid_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 106 — Topology Mermaid

## Mermaid
- mermaid_file: ${OUT_MMD}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase106 mermaid gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
sed -n '1,220p' "${OUT_MMD}"
