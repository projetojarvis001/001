#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
./scripts/load_mesh_env.sh >/dev/null
# shellcheck disable=SC1091
source .secrets/mesh_nodes.env

mkdir -p logs/executive docs/generated runtime/control_plane
TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/control_plane/phase114_mesh_http_bootstrap_apply_${TS}.txt"
OUT_JSON="logs/executive/phase114_mesh_http_bootstrap_apply_${TS}.json"
OUT_MD="docs/generated/phase114_mesh_http_bootstrap_apply_${TS}.md"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

exec > >(tee "${RAW_FILE}") 2>&1

echo "===== APPLY PHASE114 ====="

remote_bootstrap() {
  local NAME="$1"
  local HOST="$2"
  local PORT="$3"
  local USER="$4"
  local PASS="$5"

  echo
  echo "===== NODE ${NAME} ====="

  sshpass -p "${PASS}" ssh \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=8 \
    -p "${PORT}" \
    "${USER}@${HOST}" 'bash -s' <<'REMOTE'
set -euo pipefail

mkdir -p "$HOME/jarvis_mesh_runtime"

cat > "$HOME/jarvis_mesh_runtime/health_server.py" <<'PY'
#!/usr/bin/env python3
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("JARVIS_MESH_HTTP_PORT", "3010"))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/health", "/healthz", "/ready"):
            payload = {
                "status": "ok",
                "service": "mesh_health",
                "hostname": socket.gethostname()
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        return

HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PY

chmod +x "$HOME/jarvis_mesh_runtime/health_server.py"

pkill -f jarvis_mesh_runtime/health_server.py >/dev/null 2>&1 || true

nohup env JARVIS_MESH_HTTP_PORT=3010 python3 "$HOME/jarvis_mesh_runtime/health_server.py" \
  > "$HOME/jarvis_mesh_runtime/health_server.log" 2>&1 &

sleep 2

curl -fsS http://127.0.0.1:3010/health
REMOTE
}

VISION_OK=false
FRIDAY_OK=false

if remote_bootstrap "vision" "${VISION_HOST}" "${VISION_SSH_PORT}" "${VISION_SSH_USER}" "${VISION_SSH_PASS}"; then
  VISION_OK=true
fi

if remote_bootstrap "friday" "${FRIDAY_HOST}" "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}" "${FRIDAY_SSH_PASS}"; then
  FRIDAY_OK=true
fi

OVERALL_OK=false
if [ "${VISION_OK}" = true ] && [ "${FRIDAY_OK}" = true ]; then
  OVERALL_OK=true
fi

jq -n \
  --arg created_at "$CREATED_AT" \
  --arg raw_file "$RAW_FILE" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_http_bootstrap_apply: {
      raw_file: $raw_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 114 — Mesh HTTP Bootstrap Apply

## Apply
- raw_file: ${RAW_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase114 apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
