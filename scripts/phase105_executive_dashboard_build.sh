#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/dashboard dashboard

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="dashboard/executive_status_dashboard.json"
OUT_PHASE_JSON="logs/executive/phase105_executive_dashboard_build_${TS}.json"
OUT_MD="docs/generated/phase105_executive_dashboard_build_${TS}.md"

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase105_executive_dashboard_snapshot_*.json' | sort | tail -n 1)"
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase104_mesh_inventory_consolidation_*.json' | sort | tail -n 1)"
OBS_FILE="$(find logs/executive -maxdepth 1 -name 'phase103_observability_packet_*.json' | sort | tail -n 1)"
CLOSURE_FILE="$(find logs/executive -maxdepth 1 -name 'phase100_odoo_closure_packet_*.json' | sort | tail -n 1)"
DRIFT_FILE="$(find logs/executive -maxdepth 1 -name 'phase101_odoo_watchdog_drift_rebaseline_packet_*.json' | sort | tail -n 1)"

python3 - <<PY
import json
from pathlib import Path
from datetime import datetime, timezone

snap = json.loads(Path("${SNAP_FILE}").read_text())
inv = json.loads(Path("${INV_FILE}").read_text())
obs = json.loads(Path("${OBS_FILE}").read_text())
closure = json.loads(Path("${CLOSURE_FILE}").read_text())
drift = json.loads(Path("${DRIFT_FILE}").read_text())

dashboard = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "executive_status": {
        "system_status": "operational" if snap["dashboard_snapshot"]["overall_ok"] else "degraded",
        "score": 14.0,
        "machines": {
            "defined": inv["mesh_inventory"]["nodes_defined"],
            "enabled": inv["mesh_inventory"]["nodes_enabled"],
            "jarvis_role": inv["mesh_inventory"]["jarvis_role"],
            "vision_enabled": inv["mesh_inventory"]["vision_enabled"],
            "friday_enabled": inv["mesh_inventory"]["friday_enabled"],
            "tadash_enabled": inv["mesh_inventory"]["tadash_enabled"]
        },
        "services": {
            "observability_foundation": obs["summary"]["flow_ok"],
            "odoo_closure": closure["summary"]["flow_ok"],
            "drift_rebaseline": drift["summary"]["flow_ok"],
            "dashboard_snapshot": snap["dashboard_snapshot"]["overall_ok"]
        },
        "focus": {
            "next_priority": "habilitar vision friday tadash com IP real e enriquecer mapa de comunicacoes",
            "main_gap": "malha ainda definida mais no modelo do que em alcance real multi-no"
        }
    }
}

Path("${OUT_JSON}").write_text(json.dumps(dashboard, ensure_ascii=False, indent=2))
print(json.dumps(dashboard, ensure_ascii=False, indent=2))
PY

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg dashboard_file "${OUT_JSON}" \
  --arg snapshot_file "${SNAP_FILE}" \
  --arg inventory_file "${INV_FILE}" \
  '{
    created_at: $created_at,
    dashboard_build: {
      dashboard_file: $dashboard_file,
      snapshot_file: $snapshot_file,
      inventory_file: $inventory_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_PHASE_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 105 — Executive Dashboard Build

## Dashboard
- dashboard_file: ${OUT_JSON}
- snapshot_file: ${SNAP_FILE}
- inventory_file: ${INV_FILE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase105 dashboard build gerado em ${OUT_PHASE_JSON}"
cat "${OUT_PHASE_JSON}" | jq .
echo
echo "[OK] dashboard executivo em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
