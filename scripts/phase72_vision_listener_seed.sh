#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/vision/inbox logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
TASK_FILE="runtime/vision/inbox/task_${TS}.json"
OUT_JSON="logs/executive/phase72_vision_listener_seed_${TS}.json"
OUT_MD="docs/generated/phase72_vision_listener_seed_${TS}.md"

cat > "${TASK_FILE}" <<JSON
{
  "task_id": "vision-listener-task-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase72_listener_seed",
  "type": "classification",
  "input": {
    "title": "Listener classification test",
    "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel com risco controlado."
  }
}
JSON

TASK_SHA="$(shasum -a 256 "${TASK_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg task_file "${TASK_FILE}" \
  --arg task_sha "${TASK_SHA}" \
  '{
    created_at: $created_at,
    seed: {
      task_file: $task_file,
      task_sha256: $task_sha,
      source: "phase72_listener_seed"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 72 — Vision Listener Seed

## Task
- task_file: ${TASK_FILE}
- task_sha256: ${TASK_SHA}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] listener seed gerado em ${OUT_JSON}"
echo "[OK] markdown do seed gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
