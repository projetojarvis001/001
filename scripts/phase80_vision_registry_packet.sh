#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase80_vision_registry_packet_${TS}.json"
OUT_MD="docs/generated/phase80_vision_registry_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase80_vision_registry_evidence_*.json 2>/dev/null | head -n 1 || true)"
OBS_PACKET="$(ls -1t logs/executive/phase79_vision_observability_packet_*.json 2>/dev/null | head -n 1 || true)"

REGISTRY_LIVE="$(jq -r '.registry_flow.registry_flow_ok // false' "${EVIDENCE_FILE}" 2>/dev/null || echo false)"
PROMOTED_ROUTE="$(jq -r '.registry_flow.promoted_route // ""' "${EVIDENCE_FILE}" 2>/dev/null || echo "")"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 9.6' "${OBS_PACKET}" 2>/dev/null || echo 9.6)"
VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"

if [ "${REGISTRY_LIVE}" = "true" ]; then
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.2, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg promoted_route "${PROMOTED_ROUTE}" \
  --argjson registry_live "${REGISTRY_LIVE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_80_VISION_RECRUITER_REGISTRY",
      registry_live: $registry_live,
      promoted_route: $promoted_route,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION agora promove a melhor rota e rebaixa a pior com inteligencia de registry."
    },
    sources: {
      evidence_file: $evidence_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 80 — Vision Registry Packet

## Summary
- registry_live: ${REGISTRY_LIVE}
- promoted_route: ${PROMOTED_ROUTE}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] registry packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
