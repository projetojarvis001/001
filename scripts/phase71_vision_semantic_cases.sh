#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/vision/tests logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
CASES_FILE="runtime/vision/tests/semantic_cases_${TS}.json"
OUT_JSON="logs/executive/phase71_vision_semantic_cases_${TS}.json"
OUT_MD="docs/generated/phase71_vision_semantic_cases_${TS}.md"

cat > "${CASES_FILE}" <<JSON
[
  {
    "case_id": "sem_001",
    "text": "Redis respondeu normalmente. Core healthy. Nao houve rollback. Risco atual controlado.",
    "expected_classification": "healthy_controlled"
  },
  {
    "case_id": "sem_002",
    "text": "Rollback executado apos falha de deploy. Ambiente estabilizado depois.",
    "expected_classification": "attention"
  },
  {
    "case_id": "sem_003",
    "text": "Risco controlado identificado sem impacto operacional relevante.",
    "expected_classification": "risk_controlled"
  },
  {
    "case_id": "sem_004",
    "text": "Core healthy, sem incidentes, sem rollback e com operacao estavel.",
    "expected_classification": "healthy_controlled"
  },
  {
    "case_id": "sem_005",
    "text": "Falha critica com rollback falhou e ambiente instavel.",
    "expected_classification": "attention"
  }
]
JSON

CASE_COUNT="$(jq 'length' "${CASES_FILE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg cases_file "${CASES_FILE}" \
  --argjson case_count "${CASE_COUNT}" \
  '{
    created_at: $created_at,
    suite: {
      cases_file: $cases_file,
      case_count: $case_count,
      objective: "endurecer interpretacao semantica do vision"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 71 — Vision Semantic Cases

## Suite
- file: ${CASES_FILE}
- case_count: ${CASE_COUNT}

## Objetivo
- reduzir falso positivo semântico
- tratar negação
- diferenciar risco controlado de incidente
MD

echo "[OK] semantic cases gerado em ${OUT_JSON}"
echo "[OK] markdown dos casos gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
