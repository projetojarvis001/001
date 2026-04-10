#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/vision/registry logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
REGISTRY_FILE="runtime/vision/registry/route_registry_${TS}.json"
OUT_JSON="logs/executive/phase80_vision_registry_seed_${TS}.json"
OUT_MD="docs/generated/phase80_vision_registry_seed_${TS}.md"

cat > "${REGISTRY_FILE}" <<JSON
{
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "routes": [
    {
      "route": "route_primary_simulated",
      "kind": "quality_first",
      "accuracy_percent": 100.0,
      "avg_latency_ms": 85.06,
      "stability_score": 9.4,
      "status": "active_candidate"
    },
    {
      "route": "route_secondary_simulated",
      "kind": "speed_first",
      "accuracy_percent": 80.0,
      "avg_latency_ms": 34.57,
      "stability_score": 8.2,
      "status": "active_candidate"
    },
    {
      "route": "route_fallback_simulated",
      "kind": "resilience_only",
      "accuracy_percent": 78.0,
      "avg_latency_ms": 41.00,
      "stability_score": 8.0,
      "status": "backup_candidate"
    }
  ]
}
JSON

REG_SHA="$(shasum -a 256 "${REGISTRY_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg registry_file "${REGISTRY_FILE}" \
  --arg registry_sha "${REG_SHA}" \
  '{
    created_at: $created_at,
    seed: {
      registry_file: $registry_file,
      registry_sha256: $registry_sha,
      objective: "provar intelligence layer do registry do vision"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 80 — Vision Registry Seed

## Registry
- registry_file: ${REGISTRY_FILE}
- registry_sha256: ${REG_SHA}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] registry seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
