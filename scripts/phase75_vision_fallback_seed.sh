#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/vision/fallback
TS="$(date +%Y%m%d-%H%M%S)"
TASK_FILE="runtime/vision/fallback/fallback_task_${TS}.json"
OUT_JSON="logs/executive/phase75_vision_fallback_seed_${TS}.json"
OUT_MD="docs/generated/phase75_vision_fallback_seed_${TS}.md"

cat > "${TASK_FILE}" <<JSON
{
  "task_id": "vision-fallback-task-${TS}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "phase75_fallback_seed",
  "type": "classification",
  "routing": {
    "primary_model": "vision_primary_simulated",
    "fallback_model": "vision_secondary_simulated",
    "force_primary_fail": true
  },
  "input": {
    "title": "Fallback routing test",
    "text": "Risco controlado identificado. Sem rollback executado. Operacao monitorada."
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
      objective: "provar fallback controlado do vision"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 75 — Vision Fallback Seed

## Task
- task_file: ${TASK_FILE}
- task_sha256: ${TASK_SHA}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] fallback seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
