#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/control_plane logs/executive docs/generated

./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase109_mesh_activation_probe_${TS}.txt"
OUT_JSON="logs/executive/phase109_mesh_activation_probe_${TS}.json"
OUT_MD="docs/generated/phase109_mesh_activation_probe_${TS}.md"

python3 - <<'PY' > "${RAW_FILE}"
import json
import socket
import subprocess
from urllib.request import Request, urlopen

nodes = [
    {"name": "jarvis", "host": "127.0.0.1", "ssh_port": 22, "http_url": "http://127.0.0.1:3000", "enabled": True},
    {"name": "vision", "host": __import__("os").environ["VISION_HOST"], "ssh_port": int(__import__("os").environ["VISION_SSH_PORT"]), "http_url": f"http://{__import__('os').environ['VISION_HOST']}:{__import__('os').environ['VISION_HTTP_PORT']}", "enabled": True},
    {"name": "friday", "host": __import__("os").environ["FRIDAY_HOST"], "ssh_port": int(__import__("os").environ["FRIDAY_SSH_PORT"]), "http_url": f"http://{__import__('os').environ['FRIDAY_HOST']}:{__import__('os').environ['FRIDAY_HTTP_PORT']}", "enabled": True},
    {"name": "tadash", "host": __import__("os").environ["TADASH_HOST"], "ssh_port": int(__import__("os").environ["TADASH_SSH_PORT"]), "http_url": f"http://{__import__('os').environ['TADASH_HOST']}:{__import__('os').environ['TADASH_HTTP_PORT']}", "enabled": True},
]

def ping(host):
    try:
        r = subprocess.run(["ping", "-c", "1", "-W", "1000", host], capture_output=True, text=True)
        return r.returncode == 0
    except Exception:
        return False

def tcp(host, port):
    try:
        with socket.create_connection((host, port), timeout=2):
            return True
    except Exception:
        return False

def http_ok(url):
    try:
        req = Request(url, headers={"User-Agent": "jarvis-phase109"})
        with urlopen(req, timeout=4) as resp:
            return 200 <= resp.status < 500
    except Exception:
        return False

out = []
for n in nodes:
    item = {
        "name": n["name"],
        "enabled": n["enabled"],
        "host": n["host"],
        "ping_ok": ping(n["host"]),
        "tcp_ok": tcp(n["host"], n["ssh_port"]),
        "http_ok": http_ok(n["http_url"]),
    }
    out.append(item)

print(json.dumps({"nodes": out}, ensure_ascii=False, indent=2))
PY

ENABLED_TOTAL="$(jq '[.nodes[] | select(.enabled==true)] | length' "${RAW_FILE}")"
PING_OK="$(jq '[.nodes[] | select(.ping_ok==true)] | length' "${RAW_FILE}")"
TCP_OK="$(jq '[.nodes[] | select(.tcp_ok==true)] | length' "${RAW_FILE}")"
HTTP_OK="$(jq '[.nodes[] | select(.http_ok==true)] | length' "${RAW_FILE}")"

OVERALL_OK=false
[ "${ENABLED_TOTAL}" -ge 1 ] && OVERALL_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson enabled_total "${ENABLED_TOTAL}" \
  --argjson ping_ok "${PING_OK}" \
  --argjson tcp_ok "${TCP_OK}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_activation_probe: {
      raw_file: $raw_file,
      enabled_total: $enabled_total,
      ping_ok: $ping_ok,
      tcp_ok: $tcp_ok,
      http_ok: $http_ok,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 109 — Mesh Activation Probe

## Probe
- raw_file: ${RAW_FILE}
- enabled_total: ${ENABLED_TOTAL}
- ping_ok: ${PING_OK}
- tcp_ok: ${TCP_OK}
- http_ok: ${HTTP_OK}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase109 probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
