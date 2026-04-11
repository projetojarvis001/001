#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

OUT_MANIFEST="dispatcher/jobs_manifest.json"
OUT_JSON="logs/executive/phase116_mesh_dispatcher_manifest_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_manifest_${TS}.md"

cat > "${OUT_MANIFEST}" <<JSON
{
  "created_at": "${CREATED_AT}",
  "jobs": [
    {
      "id": "vision_job_001",
      "node": "vision",
      "host": "192.168.8.124",
      "command": "echo vision_dispatch_ok; hostname; whoami"
    },
    {
      "id": "friday_job_001",
      "node": "friday",
      "host": "192.168.8.36",
      "command": "echo friday_dispatch_ok; hostname; whoami"
    },
    {
      "id": "tadash_job_001",
      "node": "tadash",
      "host": "177.104.176.69",
      "command": "echo tadash_dispatch_ok; hostname; whoami"
    }
  ]
}
JSON

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg manifest_file "${OUT_MANIFEST}" \
  '{
    created_at: $created_at,
    dispatcher_manifest: {
      manifest_file: $manifest_file,
      jobs_total: 3,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 116 — Mesh Dispatcher Manifest

## Manifest
- manifest_file: ${OUT_MANIFEST}
- jobs_total: 3

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase116 manifest gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
cat "${OUT_MANIFEST}" | jq .
