#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_PHASE_JSON="logs/executive/phase112_mesh_readiness_build_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_build_${TS}.md"
OUT_STATE="readiness/mesh_readiness_state.json"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SNAP_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_snapshot_*.json' | sort | tail -n 1)"
INV_FILE="$(find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_inventory_check_*.json' | sort | tail -n 1)"

python3 - <<'PY' > "${OUT_STATE}"
import json, os, re

snap_file = os.popen("find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_snapshot_*.json' | sort | tail -n 1").read().strip()
inv_file = os.popen("find logs/executive -maxdepth 1 -name 'phase112_mesh_readiness_inventory_check_*.json' | sort | tail -n 1").read().strip()
env_file = ".secrets/mesh_nodes.env"

def read_json(path):
    with open(path, "r") as f:
        return json.load(f)

snap = read_json(snap_file)
inv = read_json(inv_file)

content = ""
if os.path.exists(env_file):
    with open(env_file, "r") as f:
        content = f.read()

def get_value(name):
    m = re.search(rf"^export {name}='?(.*?)'?$", content, re.M)
    return m.group(1).strip() if m else ""

def classify(host, user, password):
    values = [host, user, password]
    if not all(values):
        return "blocked"
    if any("COLE_AQUI" in v for v in values):
        return "blocked"
    return "ready"

vision = classify(get_value("VISION_HOST"), get_value("VISION_SSH_USER"), get_value("VISION_SSH_PASS"))
friday = classify(get_value("FRIDAY_HOST"), get_value("FRIDAY_SSH_USER"), get_value("FRIDAY_SSH_PASS"))
tadash = classify(get_value("TADASH_HOST"), get_value("TADASH_SSH_USER"), get_value("TADASH_SSH_PASS"))

ready_count = sum(1 for x in [vision, friday, tadash] if x == "ready")
blocked_count = sum(1 for x in [vision, friday, tadash] if x == "blocked")

status = "blocked_by_external_inputs" if blocked_count > 0 else "ready_for_runtime"

out = {
    "created_at": snap["created_at"],
    "mesh_readiness": {
        "snapshot_file": snap_file,
        "inventory_file": inv_file,
        "nodes": [
            {"name": "vision", "status": vision},
            {"name": "friday", "status": friday},
            {"name": "tadash", "status": tadash}
        ],
        "ready_count": ready_count,
        "blocked_count": blocked_count,
        "status": status,
        "overall_ok": True
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

READY_COUNT="$(jq -r '.mesh_readiness.ready_count' "${OUT_STATE}")"
BLOCKED_COUNT="$(jq -r '.mesh_readiness.blocked_count' "${OUT_STATE}")"
STATUS="$(jq -r '.mesh_readiness.status' "${OUT_STATE}")"

jq -n \
  --arg created_at "${created_at}" \
  --arg state_file "${OUT_STATE}" \
  --arg status "${STATUS}" \
  --argjson ready_count "${READY_COUNT}" \
  --argjson blocked_count "${BLOCKED_COUNT}" \
  '{
    created_at: $created_at,
    readiness_build: {
      state_file: $state_file,
      ready_count: $ready_count,
      blocked_count: $blocked_count,
      status: $status,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_PHASE_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 112 — Mesh Readiness Build

## Build
- state_file: ${OUT_STATE}
- ready_count: ${READY_COUNT}
- blocked_count: ${BLOCKED_COUNT}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 build gerado em ${OUT_PHASE_JSON}"
cat "${OUT_PHASE_JSON}" | jq .
echo
echo "[OK] readiness state em ${OUT_STATE}"
cat "${OUT_STATE}" | jq .
