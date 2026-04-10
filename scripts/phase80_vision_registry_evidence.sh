#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase80_vision_registry_evidence_${TS}.json"
OUT_MD="docs/generated/phase80_vision_registry_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase80_vision_registry_seed_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/registry/out/registry_result_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${SEED_FILE}" ] || [ -z "${RESULT_FILE}" ]; then
  echo "[ERRO] seed ou result file nao encontrado"
  exit 1
fi

PROMOTED_ROUTE="$(jq -r '.decision.promoted_route // ""' "${RESULT_FILE}")"
DEMOTED_ROUTE="$(jq -r '.decision.demoted_route // ""' "${RESULT_FILE}")"
REGISTRY_LIVE="$(jq -r '.decision.registry_live // false' "${RESULT_FILE}")"
RANK_COUNT="$(jq -r '.ranked_routes | length' "${RESULT_FILE}")"

FLOW_OK=false
if [ "${REGISTRY_LIVE}" = "true" ] && [ "${RANK_COUNT}" -ge 3 ] && [ -n "${PROMOTED_ROUTE}" ] && [ -n "${DEMOTED_ROUTE}" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg promoted_route "${PROMOTED_ROUTE}" \
  --arg demoted_route "${DEMOTED_ROUTE}" \
  --argjson rank_count "${RANK_COUNT}" \
  --argjson registry_live "${REGISTRY_LIVE}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    registry_flow: {
      seed_file: $seed_file,
      result_file: $result_file,
      promoted_route: $promoted_route,
      demoted_route: $demoted_route,
      rank_count: $rank_count,
      registry_live: $registry_live,
      registry_flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 80 — Vision Registry Evidence

## Flow
- promoted_route: ${PROMOTED_ROUTE}
- demoted_route: ${DEMOTED_ROUTE}
- rank_count: ${RANK_COUNT}
- registry_live: ${REGISTRY_LIVE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] registry evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
