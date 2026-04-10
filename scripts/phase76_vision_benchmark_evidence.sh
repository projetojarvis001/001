#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase76_vision_benchmark_evidence_${TS}.json"
OUT_MD="docs/generated/phase76_vision_benchmark_evidence_${TS}.md"

RESULT_FILE="$(ls -1t runtime/vision/benchmark/out/benchmark_result_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${RESULT_FILE}" ] || [ ! -f "${RESULT_FILE}" ]; then
  echo "[ERRO] benchmark result nao encontrado"
  exit 1
fi

WINNER_ROUTE="$(jq -r '.winner.route // ""' "${RESULT_FILE}")"
WINNER_ACC="$(jq -r '.winner.accuracy_percent // 0' "${RESULT_FILE}")"
WINNER_LAT="$(jq -r '.winner.avg_latency_ms // 0' "${RESULT_FILE}")"

PRIMARY_ACC="$(jq -r '.route_results[] | select(.route == "route_primary_simulated") | .accuracy_percent' "${RESULT_FILE}")"
PRIMARY_LAT="$(jq -r '.route_results[] | select(.route == "route_primary_simulated") | .avg_latency_ms' "${RESULT_FILE}")"
SECONDARY_ACC="$(jq -r '.route_results[] | select(.route == "route_secondary_simulated") | .accuracy_percent' "${RESULT_FILE}")"
SECONDARY_LAT="$(jq -r '.route_results[] | select(.route == "route_secondary_simulated") | .avg_latency_ms' "${RESULT_FILE}")"

BENCHMARK_OK=false
if [ -n "${WINNER_ROUTE}" ]; then
  BENCHMARK_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg result_file "${RESULT_FILE}" \
  --arg winner_route "${WINNER_ROUTE}" \
  --arg winner_acc "${WINNER_ACC}" \
  --arg winner_lat "${WINNER_LAT}" \
  --arg primary_acc "${PRIMARY_ACC}" \
  --arg primary_lat "${PRIMARY_LAT}" \
  --arg secondary_acc "${SECONDARY_ACC}" \
  --arg secondary_lat "${SECONDARY_LAT}" \
  --argjson benchmark_ok "${BENCHMARK_OK}" \
  '{
    created_at: $created_at,
    benchmark_flow: {
      result_file: $result_file,
      winner_route: $winner_route,
      winner_accuracy_percent: ($winner_acc | tonumber),
      winner_avg_latency_ms: ($winner_lat | tonumber),
      primary: {
        accuracy_percent: ($primary_acc | tonumber),
        avg_latency_ms: ($primary_lat | tonumber)
      },
      secondary: {
        accuracy_percent: ($secondary_acc | tonumber),
        avg_latency_ms: ($secondary_lat | tonumber)
      },
      benchmark_ok: $benchmark_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 76 — Vision Benchmark Evidence

## Winner
- winner_route: ${WINNER_ROUTE}
- winner_accuracy_percent: ${WINNER_ACC}
- winner_avg_latency_ms: ${WINNER_LAT}

## Primary
- accuracy_percent: ${PRIMARY_ACC}
- avg_latency_ms: ${PRIMARY_LAT}

## Secondary
- accuracy_percent: ${SECONDARY_ACC}
- avg_latency_ms: ${SECONDARY_LAT}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] benchmark evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
