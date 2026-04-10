#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/vision/memory logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
MEMORY_FILE="runtime/vision/memory/context_events_${TS}.jsonl"
TASK_FILE="runtime/vision/memory/context_task_${TS}.json"
OUT_JSON="logs/executive/phase78_vision_memory_seed_${TS}.json"
OUT_MD="docs/generated/phase78_vision_memory_seed_${TS}.md"

cat > "${MEMORY_FILE}" <<JSONL
{"event_id":"ctx-${TS}-01","created_at":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","classification":"attention","summary":"Rollback executado anteriormente no modulo bridge.","source":"history"}
{"event_id":"ctx-${TS}-02","created_at":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","classification":"risk_controlled","summary":"Depois do rollback, ambiente estabilizou sob monitoramento.","source":"history"}
JSONL

cat > "${TASK_FILE}" <<JSON
{
  "task_id": "vision-memory-task-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "memory_file": "${MEMORY_FILE}",
  "input": {
    "text": "Ambiente segue estavel, sem novo rollback, mas ainda sob observacao apos evento anterior."
  }
}
JSON

MEM_SHA="$(shasum -a 256 "${MEMORY_FILE}" | awk '{print $1}')"
TASK_SHA="$(shasum -a 256 "${TASK_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg memory_file "${MEMORY_FILE}" \
  --arg task_file "${TASK_FILE}" \
  --arg memory_sha "${MEM_SHA}" \
  --arg task_sha "${TASK_SHA}" \
  '{
    created_at: $created_at,
    seed: {
      memory_file: $memory_file,
      task_file: $task_file,
      memory_sha256: $memory_sha,
      task_sha256: $task_sha,
      objective: "provar memoria contextual do vision"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 78 — Vision Memory Seed

## Arquivos
- memory_file: ${MEMORY_FILE}
- task_file: ${TASK_FILE}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] memory seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
