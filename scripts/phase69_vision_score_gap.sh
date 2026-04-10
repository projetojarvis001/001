#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase69_vision_score_gap_${TS}.json"
OUT_MD="docs/generated/phase69_vision_score_gap_${TS}.md"

READINESS_FILE="$(ls -1t logs/executive/phase69_vision_readiness_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${READINESS_FILE}" ] || [ ! -f "${READINESS_FILE}" ]; then
  echo "[ERRO] readiness da fase 69 nao encontrado"
  exit 1
fi

READINESS_SCORE="$(jq -r '.readiness.readiness_score // 0' "${READINESS_FILE}" 2>/dev/null || echo 0)"

BASE_SCORE="6.4"
if [ "${READINESS_SCORE}" -ge 80 ]; then
  BASE_SCORE="6.8"
elif [ "${READINESS_SCORE}" -ge 60 ]; then
  BASE_SCORE="6.6"
fi

GAP_TO_10="$(python3 - <<PY
base = float("${BASE_SCORE}")
print(f"{10 - base:.1f}")
PY
)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg readiness_file "${READINESS_FILE}" \
  --argjson readiness_score "${READINESS_SCORE}" \
  --arg base_score "${BASE_SCORE}" \
  --arg gap_to_10 "${GAP_TO_10}" \
  '{
    created_at: $created_at,
    vision: {
      base_score: ($base_score | tonumber),
      target_score: 10,
      gap_to_10: ($gap_to_10 | tonumber),
      readiness_score: $readiness_score
    },
    immediate_gaps: [
      "listener_real_nao_comprovado",
      "benchmark_de_modelos_nao_operacionalizado",
      "fallback_entre_modelos_nao_comprovado",
      "observabilidade_real_do_vision_nao_consolidada",
      "memoria_contextual_nao_evidenciada"
    ],
    decision: {
      operator_note: "VISION ja tem sinais de base, mas ainda nao provou fluxo vivo ponta a ponta."
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 69 — VISION Score Gap

## Score
- base_score: ${BASE_SCORE}
- target_score: 10
- gap_to_10: ${GAP_TO_10}
- readiness_score: ${READINESS_SCORE}

## Gaps imediatos
- listener real não comprovado
- benchmark de modelos não operacionalizado
- fallback entre modelos não comprovado
- observabilidade real não consolidada
- memória contextual não evidenciada
MD

echo "[OK] vision score gap gerado em ${OUT_JSON}"
echo "[OK] markdown do score gap gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
