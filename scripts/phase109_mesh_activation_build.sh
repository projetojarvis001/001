#!/usr/bin/env bash
set -euo pipefail

mkdir -p control_plane logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_STATE="control_plane/mesh_control_plane_state.json"
OUT_JSON="logs/executive/phase109_mesh_activation_build_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_build_${TS}.md"

INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_inventory_render_*.json' | sort | tail -n 1)"
PROBE_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_probe_*.json' | sort | tail -n 1)"
HEALTH_FILE="$(find logs/executive -maxdepth 1 -name 'phase109_mesh_activation_remote_health_*.json' | sort | tail -n 1)"

python3 - <<PY > "${OUT_STATE}"
import json
from pathlib import Path

inv = json.loads(Path("${INV_FILE}").read_text()) if "${INV_FILE}" else {}
probe = json.loads(Path("${PROBE_FILE}").read_text()) if "${PROBE_FILE}" else {}
health = json.loads(Path("${HEALTH_FILE}").read_text()) if "${HEALTH_FILE}" else {}

enabled_total = probe.get("mesh_activation_probe", {}).get("enabled_total", 0)
ping_ok = probe.get("mesh_activation_probe", {}).get("ping_ok", 0)
tcp_ok = probe.get("mesh_activation_probe", {}).get("tcp_ok", 0)
http_ok = probe.get("mesh_activation_probe", {}).get("http_ok", 0)

out = {
  "created_at": __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "mesh_control_plane": {
    "inventory_render_file": "${INV_FILE}",
    "probe_file": "${PROBE_FILE}",
    "remote_health_file": "${HEALTH_FILE}",
    "enabled_total": enabled_total,
    "ping_ok": ping_ok,
    "tcp_ok": tcp_ok,
    "http_ok": http_ok,
    "vision_health_ok": health.get("remote_health", {}).get("vision_ok", False),
    "friday_health_ok": health.get("remote_health", {}).get("friday_ok", False),
    "tadash_health_ok": health.get("remote_health", {}).get("tadash_ok", False),
    "status": "multi_node_partial" if enabled_total > 1 else "single_node_only",
    "overall_ok": True
  }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

ENABLED_TOTAL="$(jq -r '.mesh_control_plane.enabled_total' "${OUT_STATE}")"
STATUS="$(jq -r '.mesh_control_plane.status' "${OUT_STATE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg control_plane_file "${OUT_STATE}" \
  --argjson enabled_total "${ENABLED_TOTAL}" \
  --arg status "${STATUS}" \
  '{
    created_at: $created_at,
    mesh_activation_build: {
      control_plane_file: $control_plane_file,
      enabled_total: $enabled_total,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 109 — Mesh Activation Build

## Build
- control_plane_file: ${OUT_STATE}
- enabled_total: ${ENABLED_TOTAL}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 build gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] control plane em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
