#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

if [ -z "${REDIS_PASSWORD:-}" ]; then
  echo "[ERRO] REDIS_PASSWORD nao exportada"
  exit 1
fi

QUEUE_NAME="${VISION_REDIS_QUEUE:-vision_tasks}"
mkdir -p logs/executive docs/generated runtime/vision/redis
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase74_vision_batch_seed_${TS}.json"
OUT_MD="docs/generated/phase74_vision_batch_seed_${TS}.md"

TASK1="runtime/vision/redis/batch_task_${TS}_01.json"
TASK2="runtime/vision/redis/batch_task_${TS}_02.json"
TASK3="runtime/vision/redis/batch_task_${TS}_03.json"

cat > "${TASK1}" <<JSON
{
  "task_id": "vision-batch-task-${TS}-01",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase74_batch_seed",
  "type": "classification",
  "input": {
    "title": "Batch case 01",
    "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel."
  }
}
JSON

cat > "${TASK2}" <<JSON
{
  "task_id": "vision-batch-task-${TS}-02",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase74_batch_seed",
  "type": "classification",
  "input": {
    "title": "Batch case 02",
    "text": "Risco controlado identificado. Sem evento critico. Operacao monitorada."
  }
}
JSON

cat > "${TASK3}" <<JSON
{
  "task_id": "vision-batch-task-${TS}-03",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase74_batch_seed",
  "type": "classification",
  "input": {
    "title": "Batch case 03",
    "text": "Houve rollback executado e ambiente instavel."
  }
}
JSON

P1="$(docker exec redis redis-cli -a "${REDIS_PASSWORD}" LPUSH "${QUEUE_NAME}" "$(cat "${TASK1}")")"
P2="$(docker exec redis redis-cli -a "${REDIS_PASSWORD}" LPUSH "${QUEUE_NAME}" "$(cat "${TASK2}")")"
P3="$(docker exec redis redis-cli -a "${REDIS_PASSWORD}" LPUSH "${QUEUE_NAME}" "$(cat "${TASK3}")")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg queue_name "${QUEUE_NAME}" \
  --arg task1 "${TASK1}" \
  --arg task2 "${TASK2}" \
  --arg task3 "${TASK3}" \
  --arg p1 "${P1}" \
  --arg p2 "${P2}" \
  --arg p3 "${P3}" \
  '{
    created_at: $created_at,
    batch_seed: {
      queue_name: $queue_name,
      tasks: [$task1, $task2, $task3],
      push_replies: [$p1, $p2, $p3],
      task_count: 3
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 74 — Vision Batch Seed

## Queue
- queue_name: ${QUEUE_NAME}
- task_count: 3
- push_replies: ${P1}, ${P2}, ${P3}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] batch seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
