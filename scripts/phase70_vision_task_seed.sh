#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/vision/inbox logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
TASK_FILE="runtime/vision/inbox/task_${TS}.json"
OUT_JSON="logs/executive/phase70_vision_task_seed_${TS}.json"
OUT_MD="docs/generated/phase70_vision_task_seed_${TS}.md"

cat > "${TASK_FILE}" <<JSON
{
  "task_id": "vision-task-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase70_controlled_seed",
  "type": "classification",
  "input": {
    "title": "Classificar evento operacional",
    "text": "Redis respondeu normalmente. Core healthy. Nao houve rollback. Risco atual controlado."
  },
  "expected_contract": {
    "must_return_fields": ["task_id", "status", "summary", "classification", "confidence"],
    "status_allowed": ["processed"]
  }
}
JSON

TASK_SHA="$(shasum -a 256 "${TASK_FILE}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg task_file "${TASK_FILE}" \
  --arg task_sha256 "${TASK_SHA}" \
  '{
    created_at: $created_at,
    seed: {
      task_file: $task_file,
      task_sha256: $task_sha256,
      contract: "vision_controlled_task_v1"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 70 — Vision Task Seed

## Task
- file: ${TASK_FILE}
- sha256: ${TASK_SHA}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] vision task seed gerado em ${OUT_JSON}"
echo "[OK] markdown do seed gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
