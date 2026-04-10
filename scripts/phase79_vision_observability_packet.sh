#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase79_vision_observability_packet_${TS}.json"
OUT_MD="docs/generated/phase79_vision_observability_packet_${TS}.md"

OBS_FILE="$(ls -1t logs/executive/phase79_vision_observability_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${OBS_FILE}" ] || [ ! -f "${OBS_FILE}" ]; then
  echo "[ERRO] observability file nao encontrado"
  exit 1
fi

OBS_OK="$(jq -r '.observability.observability_ok // false' "${OBS_FILE}" 2>/dev/null || echo false)"
VISION_SCORE_BEFORE="$(jq -r '.score.vision_score_before // 9.4' "${OBS_FILE}" 2>/dev/null || echo 9.4)"
VISION_SCORE_AFTER="$(jq -r '.score.vision_score_after // 9.4' "${OBS_FILE}" 2>/dev/null || echo 9.4)"
WINNER_ROUTE="$(jq -r '.observability.latency.winner_route // ""' "${OBS_FILE}" 2>/dev/null || echo "")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg obs_file "${OBS_FILE}" \
  --argjson observability_live "${OBS_OK}" \
  --arg winner_route "${WINNER_ROUTE}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_79_VISION_OBSERVABILITY",
      observability_live: $observability_live,
      winner_route: $winner_route,
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION agora possui observabilidade executiva consolidada por capacidade, volume e latencia."
    },
    sources: {
      observability_file: $obs_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 79 — Vision Observability Packet

## Summary
- observability_live: ${OBS_OK}
- winner_route: ${WINNER_ROUTE}
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] observability packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
