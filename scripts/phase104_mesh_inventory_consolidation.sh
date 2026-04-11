#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase104_mesh_inventory_consolidation_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_consolidation_${TS}.md"

LOCAL_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_local_snapshot_*.json' | sort | tail -n 1)"
REACH_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_reachability_probe_*.json' | sort | tail -n 1)"

python3 - <<PY > "${OUT_JSON}"
import json, yaml
from pathlib import Path
from datetime import datetime, timezone

nodes = yaml.safe_load(Path("inventory/nodes.yml").read_text())["nodes"]
local = json.loads(Path("${LOCAL_FILE}").read_text())
reach = json.loads(Path("${REACH_FILE}").read_text())

out = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mesh_inventory": {
        "nodes_defined": len(nodes),
        "nodes_enabled": sum(1 for n in nodes if n.get("enabled")),
        "local_snapshot_ok": local["local_snapshot"]["overall_ok"],
        "reachability_ok": reach["reachability_probe"]["overall_ok"],
        "jarvis_role": next((n["role"] for n in nodes if n["name"] == "jarvis"), "unknown"),
        "vision_enabled": any(n["name"] == "vision" and n.get("enabled") for n in nodes),
        "friday_enabled": any(n["name"] == "friday" and n.get("enabled") for n in nodes),
        "tadash_enabled": any(n["name"] == "tadash" and n.get("enabled") for n in nodes),
        "overall_ok": (
            local["local_snapshot"]["overall_ok"]
            and reach["reachability_probe"]["overall_ok"]
        )
    },
    "sources": {
        "local_snapshot_file": "${LOCAL_FILE}",
        "reachability_file": "${REACH_FILE}"
    },
    "governance": {
        "deploy_executed": False,
        "production_changed": False
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

NODES_DEFINED="$(jq -r '.mesh_inventory.nodes_defined' "${OUT_JSON}")"
NODES_ENABLED="$(jq -r '.mesh_inventory.nodes_enabled' "${OUT_JSON}")"
OVERALL_OK="$(jq -r '.mesh_inventory.overall_ok' "${OUT_JSON}")"

cat > "${OUT_MD}" <<MD
# FASE 104 — Mesh Inventory Consolidation

## Consolidation
- nodes_defined: ${NODES_DEFINED}
- nodes_enabled: ${NODES_ENABLED}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 consolidation gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
