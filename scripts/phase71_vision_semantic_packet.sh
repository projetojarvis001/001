#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase71_vision_semantic_packet_${TS}.json"
OUT_MD="docs/generated/phase71_vision_semantic_packet_${TS}.md"

SCORE_FILE="$(ls -1t logs/executive/phase71_vision_semantic_score_*.json 2>/dev/null | head -n 1 || true)"
ACCURACY="$(jq -r '.semantic_validation.accuracy_percent // 0' "${SCORE_FILE}" 2>/dev/null || echo 0)"
VISION_SCORE_AFTER="$(jq -r '.score.vision_score_after // 0' "${SCORE_FILE}" 2>/dev/null || echo 0)"

NEGATION_FIXED=false
if python3 - <<PY
acc = float("${ACCURACY}")
raise SystemExit(0 if acc >= 80 else 1)
PY
then
  NEGATION_FIXED=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg score_file "${SCORE_FILE}" \
  --argjson negation_fixed "${NEGATION_FIXED}" \
  --arg vision_score_after "${VISION_SCORE_AFTER}" \
  --arg accuracy "${ACCURACY}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_71_VISION_SEMANTIC_HARDENING",
      negation_fixed: $negation_fixed,
      accuracy_percent: ($accuracy | tonumber),
      vision_score_after: ($vision_score_after | tonumber)
    },
    decision: {
      operator_note: "VISION deixou de confundir parte relevante das negacoes semanticas."
    },
    sources: {
      score_file: $score_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 71 — Vision Semantic Packet

## Summary
- negation_fixed: ${NEGATION_FIXED}
- accuracy_percent: ${ACCURACY}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] semantic packet gerado em ${OUT_JSON}"
echo "[OK] markdown do packet gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
