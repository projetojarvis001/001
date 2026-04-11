#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/inventory

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/inventory/phase104_reachability_probe_${TS}.txt"
OUT_JSON="logs/executive/phase104_mesh_inventory_reachability_probe_${TS}.json"
OUT_MD="docs/generated/phase104_mesh_inventory_reachability_probe_${TS}.md"

python3 - <<'PY' > "${RAW_FILE}"
try:
    import yaml
except ModuleNotFoundError:
    raise SystemExit("[ERRO] modulo PyYAML ausente. Rode: python3 -m pip install --user pyyaml")

import socket
import subprocess
from pathlib import Path

p = Path("inventory/nodes.yml")
data = yaml.safe_load(p.read_text())

print("===== REACHABILITY =====")
for node in data["nodes"]:
    name = node["name"]
    host = str(node["host"])
    port = int(node["ssh_port"])
    enabled = bool(node["enabled"])

    print(f"[NODE] {name}")
    print(f"enabled={str(enabled).lower()}")
    print(f"host={host}")
    print(f"ssh_port={port}")

    if not enabled:
        print("ping_ok=skipped")
        print("tcp_ok=skipped")
        print()
        continue

    ping_ok = False
    tcp_ok = False

    try:
        r = subprocess.run(
            ["ping", "-c", "1", host],
            capture_output=True,
            text=True
        )
        ping_ok = (r.returncode == 0)
    except Exception:
        ping_ok = False

    try:
        with socket.create_connection((host, port), timeout=3):
            tcp_ok = True
    except Exception:
        tcp_ok = False

    print(f"ping_ok={str(ping_ok).lower()}")
    print(f"tcp_ok={str(tcp_ok).lower()}")
    print()
PY

TOTAL_ENABLED="$(grep -c 'enabled=true' "${RAW_FILE}" || true)"
PING_TRUE="$(grep -c 'ping_ok=true' "${RAW_FILE}" || true)"
TCP_TRUE="$(grep -c 'tcp_ok=true' "${RAW_FILE}" || true)"

PROBE_OK=false
grep -q '\[NODE\] jarvis' "${RAW_FILE}" && PROBE_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg total_enabled "${TOTAL_ENABLED}" \
  --arg ping_true "${PING_TRUE}" \
  --arg tcp_true "${TCP_TRUE}" \
  --argjson probe_ok "${PROBE_OK}" \
  '{
    created_at: $created_at,
    reachability_probe: {
      raw_file: $raw_file,
      total_enabled: ($total_enabled|tonumber),
      ping_true: ($ping_true|tonumber),
      tcp_true: ($tcp_true|tonumber),
      probe_ok: $probe_ok,
      overall_ok: $probe_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 104 — Mesh Inventory Reachability Probe

## Reachability
- raw_file: ${RAW_FILE}
- total_enabled: ${TOTAL_ENABLED}
- ping_true: ${PING_TRUE}
- tcp_true: ${TCP_TRUE}
- probe_ok: ${PROBE_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase104 reachability probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
