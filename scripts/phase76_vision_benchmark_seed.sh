#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/vision/benchmark
TS="$(date +%Y%m%d-%H%M%S)"
SUITE_FILE="runtime/vision/benchmark/benchmark_suite_${TS}.json"
OUT_JSON="logs/executive/phase76_vision_benchmark_seed_${TS}.json"
OUT_MD="docs/generated/phase76_vision_benchmark_seed_${TS}.md"

cat > "${SUITE_FILE}" <<JSON
{
  "suite_id": "vision-benchmark-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "routes": [
    "route_primary_simulated",
    "route_secondary_simulated"
  ],
  "cases": [
    {
      "case_id": "bench_001",
      "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel.",
      "expected_classification": "healthy_controlled"
    },
    {
      "case_id": "bench_002",
      "text": "Risco controlado identificado. Operacao monitorada. Sem evento critico.",
      "expected_classification": "risk_controlled"
    },
    {
      "case_id": "bench_003",
      "text": "Houve rollback executado e ambiente instavel.",
      "expected_classification": "attention"
    },
    {
      "case_id": "bench_004",
      "text": "Sem rollback. Healthy. Respondeu normalmente.",
      "expected_classification": "healthy_controlled"
    },
    {
      "case_id": "bench_005",
      "text": "Falha critica e instabilidade persistente.",
      "expected_classification": "attention"
    }
  ]
}
JSON

SUITE_SHA="$(shasum -a 256 "${SUITE_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg suite_file "${SUITE_FILE}" \
  --arg suite_sha256 "${SUITE_SHA}" \
  '{
    created_at: $created_at,
    seed: {
      suite_file: $suite_file,
      suite_sha256: $suite_sha256,
      objective: "comparar rotas do vision por acuracia e tempo"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 76 — Vision Benchmark Seed

## Suite
- suite_file: ${SUITE_FILE}
- suite_sha256: ${SUITE_SHA}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] benchmark seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
