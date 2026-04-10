#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

QUEUE_NAME="${VISION_REDIS_QUEUE:-vision_tasks}"
mkdir -p logs/executive docs/generated runtime/vision/redis
TS="$(date +%Y%m%d-%H%M%S)"
TASK_FILE="runtime/vision/redis/redis_task_${TS}.json"
OUT_JSON="logs/executive/phase73_vision_redis_publish_${TS}.json"
OUT_MD="docs/generated/phase73_vision_redis_publish_${TS}.md"

cat > "${TASK_FILE}" <<JSON
{
  "task_id": "vision-redis-task-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase73_redis_publish",
  "type": "classification",
  "input": {
    "title": "Redis queue classification test",
    "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel."
  }
}
JSON

if [ -n "${REDIS_PASSWORD:-}" ]; then
  PUSH_REPLY="$(docker exec redis redis-cli -a "${REDIS_PASSWORD}" LPUSH "${QUEUE_NAME}" "$(cat "${TASK_FILE}")")"
  AUTH_MODE="password"
else
  PUSH_REPLY="$(docker exec redis redis-cli LPUSH "${QUEUE_NAME}" "$(cat "${TASK_FILE}")")"
  AUTH_MODE="no_password"
fi

TASK_SHA="$(shasum -a 256 "${TASK_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg queue_name "${QUEUE_NAME}" \
  --arg task_file "${TASK_FILE}" \
  --arg task_sha256 "${TASK_SHA}" \
  --arg push_reply "${PUSH_REPLY}" \
  --arg auth_mode "${AUTH_MODE}" \
  '{
    created_at: $created_at,
    publish: {
      queue_name: $queue_name,
      task_file: $task_file,
      task_sha256: $task_sha256,
      push_reply: $push_reply,
      auth_mode: $auth_mode
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 73A — Vision Redis Publish

## Publish
- queue_name: ${QUEUE_NAME}
- task_file: ${TASK_FILE}
- task_sha256: ${TASK_SHA}
- push_reply: ${PUSH_REPLY}
- auth_mode: ${AUTH_MODE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] redis publish gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
