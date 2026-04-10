#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase79_vision_observability_${TS}.json"
OUT_MD="docs/generated/phase79_vision_observability_${TS}.md"

SEM_PACKET="$(ls -1t logs/executive/phase71_vision_semantic_packet_*.json 2>/dev/null | head -n 1 || true)"
LIVE_PACKET="$(ls -1t logs/executive/phase70_vision_first_live_packet_*.json 2>/dev/null | head -n 1 || true)"
LISTENER_PACKET="$(ls -1t logs/executive/phase72_vision_listener_packet_*.json 2>/dev/null | head -n 1 || true)"
REDIS_PACKET="$(ls -1t logs/executive/phase73_vision_redis_packet_*.json 2>/dev/null | head -n 1 || true)"
BATCH_PACKET="$(ls -1t logs/executive/phase74_vision_batch_packet_*.json 2>/dev/null | head -n 1 || true)"
FALLBACK_PACKET="$(ls -1t logs/executive/phase75_vision_fallback_packet_*.json 2>/dev/null | head -n 1 || true)"
BENCH_PACKET="$(ls -1t logs/executive/phase76_vision_benchmark_packet_*.json 2>/dev/null | head -n 1 || true)"
POLICY_PACKET="$(ls -1t logs/executive/phase77_vision_policy_packet_*.json 2>/dev/null | head -n 1 || true)"
MEMORY_PACKET="$(ls -1t logs/executive/phase78_vision_memory_packet_*.json 2>/dev/null | head -n 1 || true)"

REDIS_RESULT_COUNT="$(find runtime/vision/outbox -maxdepth 1 -type f -name 'redis_result_*.json' | wc -l | tr -d ' ')"
BATCH_RESULT_COUNT="$(find runtime/vision/outbox -maxdepth 1 -type f -name 'redis_result_vision-batch-task-*.json' | wc -l | tr -d ' ')"
POLICY_RESULT_COUNT="$(find runtime/vision/policy/out -maxdepth 1 -type f -name 'policy_result_*.json' | wc -l | tr -d ' ')"
MEMORY_RESULT_COUNT="$(find runtime/vision/memory/out -maxdepth 1 -type f -name 'memory_result_*.json' | wc -l | tr -d ' ')"
FALLBACK_RESULT_COUNT="$(find runtime/vision/fallback/out -maxdepth 1 -type f -name 'fallback_result_*.json' | wc -l | tr -d ' ')"
BENCH_RESULT_COUNT="$(find runtime/vision/benchmark/out -maxdepth 1 -type f -name 'benchmark_result_*.json' | wc -l | tr -d ' ')"

ROUTING_LIVE="$(jq -r '.summary.routing_live // false' "${POLICY_PACKET}" 2>/dev/null || echo false)"
MEMORY_LIVE="$(jq -r '.summary.memory_live // false' "${MEMORY_PACKET}" 2>/dev/null || echo false)"
BENCH_LIVE="$(jq -r '.summary.benchmark_live // false' "${BENCH_PACKET}" 2>/dev/null || echo false)"
QUEUE_LIVE="$(jq -r '.summary.queue_live // false' "${REDIS_PACKET}" 2>/dev/null || echo false)"
BATCH_LIVE="$(jq -r '.summary.batch_live // false' "${BATCH_PACKET}" 2>/dev/null || echo false)"
FALLBACK_LIVE="$(jq -r '.summary.fallback_live // false' "${FALLBACK_PACKET}" 2>/dev/null || echo false)"
LISTENER_LIVE="$(jq -r '.summary.listener_live // false' "${LISTENER_PACKET}" 2>/dev/null || echo false)"

WINNER_ROUTE="$(jq -r '.summary.winner_route // ""' "${BENCH_PACKET}" 2>/dev/null || echo "")"
VISION_SCORE_BEFORE="$(jq -r '.summary.vision_score_after // 9.4' "${MEMORY_PACKET}" 2>/dev/null || echo 9.4)"

BENCH_EVIDENCE="$(ls -1t logs/executive/phase76_vision_benchmark_evidence_*.json 2>/dev/null | head -n 1 || true)"
PRIMARY_LATENCY="$(jq -r '.benchmark_flow.primary.avg_latency_ms // 0' "${BENCH_EVIDENCE}" 2>/dev/null || echo 0)"
SECONDARY_LATENCY="$(jq -r '.benchmark_flow.secondary.avg_latency_ms // 0' "${BENCH_EVIDENCE}" 2>/dev/null || echo 0)"

OBS_OK=false
if [ "${ROUTING_LIVE}" = "true" ] && [ "${MEMORY_LIVE}" = "true" ] && [ "${BENCH_LIVE}" = "true" ] && [ "${QUEUE_LIVE}" = "true" ]; then
  OBS_OK=true
fi

VISION_SCORE_AFTER="${VISION_SCORE_BEFORE}"
if [ "${OBS_OK}" = "true" ]; then
  VISION_SCORE_AFTER="$(python3 - <<PY
before = float("${VISION_SCORE_BEFORE}")
print(f"{min(before + 0.2, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg sem_packet "${SEM_PACKET}" \
  --arg live_packet "${LIVE_PACKET}" \
  --arg listener_packet "${LISTENER_PACKET}" \
  --arg redis_packet "${REDIS_PACKET}" \
  --arg batch_packet "${BATCH_PACKET}" \
  --arg fallback_packet "${FALLBACK_PACKET}" \
  --arg bench_packet "${BENCH_PACKET}" \
  --arg policy_packet "${POLICY_PACKET}" \
  --arg memory_packet "${MEMORY_PACKET}" \
  --argjson redis_result_count "${REDIS_RESULT_COUNT}" \
  --argjson batch_result_count "${BATCH_RESULT_COUNT}" \
  --argjson policy_result_count "${POLICY_RESULT_COUNT}" \
  --argjson memory_result_count "${MEMORY_RESULT_COUNT}" \
  --argjson fallback_result_count "${FALLBACK_RESULT_COUNT}" \
  --argjson bench_result_count "${BENCH_RESULT_COUNT}" \
  --argjson routing_live "${ROUTING_LIVE}" \
  --argjson memory_live "${MEMORY_LIVE}" \
  --argjson bench_live "${BENCH_LIVE}" \
  --argjson queue_live "${QUEUE_LIVE}" \
  --argjson batch_live "${BATCH_LIVE}" \
  --argjson fallback_live "${FALLBACK_LIVE}" \
  --argjson listener_live "${LISTENER_LIVE}" \
  --arg winner_route "${WINNER_ROUTE}" \
  --argjson primary_latency "${PRIMARY_LATENCY}" \
  --argjson secondary_latency "${SECONDARY_LATENCY}" \
  --argjson observability_ok "${OBS_OK}" \
  --arg score_before "${VISION_SCORE_BEFORE}" \
  --arg score_after "${VISION_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    observability: {
      packets: {
        semantic: $sem_packet,
        live_flow: $live_packet,
        listener: $listener_packet,
        redis: $redis_packet,
        batch: $batch_packet,
        fallback: $fallback_packet,
        benchmark: $bench_packet,
        policy: $policy_packet,
        memory: $memory_packet
      },
      counters: {
        redis_results: $redis_result_count,
        batch_results: $batch_result_count,
        policy_results: $policy_result_count,
        memory_results: $memory_result_count,
        fallback_results: $fallback_result_count,
        benchmark_results: $bench_result_count
      },
      live_capabilities: {
        routing_live: $routing_live,
        memory_live: $memory_live,
        benchmark_live: $bench_live,
        queue_live: $queue_live,
        batch_live: $batch_live,
        fallback_live: $fallback_live,
        listener_live: $listener_live
      },
      latency: {
        winner_route: $winner_route,
        primary_avg_latency_ms: $primary_latency,
        secondary_avg_latency_ms: $secondary_latency
      },
      observability_ok: $observability_ok
    },
    score: {
      vision_score_before: ($score_before | tonumber),
      vision_score_after: ($score_after | tonumber)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 79 — Vision Observability

## Live capabilities
- routing_live: ${ROUTING_LIVE}
- memory_live: ${MEMORY_LIVE}
- benchmark_live: ${BENCH_LIVE}
- queue_live: ${QUEUE_LIVE}
- batch_live: ${BATCH_LIVE}
- fallback_live: ${FALLBACK_LIVE}
- listener_live: ${LISTENER_LIVE}

## Counters
- redis_results: ${REDIS_RESULT_COUNT}
- batch_results: ${BATCH_RESULT_COUNT}
- policy_results: ${POLICY_RESULT_COUNT}
- memory_results: ${MEMORY_RESULT_COUNT}
- fallback_results: ${FALLBACK_RESULT_COUNT}
- benchmark_results: ${BENCH_RESULT_COUNT}

## Latency
- winner_route: ${WINNER_ROUTE}
- primary_avg_latency_ms: ${PRIMARY_LATENCY}
- secondary_avg_latency_ms: ${SECONDARY_LATENCY}

## Score
- vision_score_before: ${VISION_SCORE_BEFORE}
- vision_score_after: ${VISION_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] vision observability gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
