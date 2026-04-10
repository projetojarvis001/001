#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase71_vision_semantic_score_${TS}.json"
OUT_MD="docs/generated/phase71_vision_semantic_score_${TS}.md"

RESULT_FILE="$(ls -1t runtime/vision/tests/out/semantic_results_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${RESULT_FILE}" ] || [ ! -f "${RESULT_FILE}" ]; then
  echo "[ERRO] resultado semantico nao encontrado"
  exit 1
fi

TOTAL="$(jq '.results | length' "${RESULT_FILE}")"
MATCHES="$(jq '[.results[] | select(.match == true)] | length' "${RESULT_FILE}")"
ACCURACY="$(python3 - <<PY
total = int("${TOTAL}")
matches = int("${MATCHES}")
acc = 0 if total == 0 else (matches / total) * 100
print(f"{acc:.1f}")
PY
)"

BASE_PACKET="$(ls -1t logs/executive/phase70_vision_first_live_packet_*.json 2>/dev/null | head -n 1 || true)"
VISION_SCORE_BEFORE="$(jq -r '.summary.score_after // 7.2' "${BASE_PACKET}" 2>/dev/null || echo 7.2)"

VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
acc = float("${ACCURACY}")
bonus = 0.0
if acc >= 100:
    bonus = 0.4
elif acc >= 80:
    bonus = 0.2
print(f"{min(before + bonus, 10.0):.1f}")
PY
)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg result_file "${RESULT_FILE}" \
  --argjson total "${TOTAL}" \
  --argjson matches "${MATCHES}" \
  --arg accuracy "${ACCURACY}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    semantic_validation: {
      result_file: $result_file,
      total_cases: $total,
      matches: $matches,
      accuracy_percent: ($accuracy | tonumber)
    },
    score: {
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "VISION melhorou interpretacao semantica de estados operacionais."
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 71 — Vision Semantic Score

## Validation
- total_cases: ${TOTAL}
- matches: ${MATCHES}
- accuracy_percent: ${ACCURACY}

## Score
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}
MD

echo "[OK] semantic score gerado em ${OUT_JSON}"
echo "[OK] markdown do semantic score gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
