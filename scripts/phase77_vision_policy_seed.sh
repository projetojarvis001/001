#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/vision/policy

TS="$(date +%Y%m%d-%H%M%S)"
TASK1="runtime/vision/policy/policy_task_${TS}_quality.json"
TASK2="runtime/vision/policy/policy_task_${TS}_speed.json"
OUT_JSON="logs/executive/phase77_vision_policy_seed_${TS}.json"
OUT_MD="docs/generated/phase77_vision_policy_seed_${TS}.md"

cat > "${TASK1}" <<JSON
{
  "task_id": "vision-policy-task-${TS}-quality",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "policy": "quality_first",
  "input": {
    "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel."
  }
}
JSON

cat > "${TASK2}" <<JSON
{
  "task_id": "vision-policy-task-${TS}-speed",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "policy": "speed_first",
  "input": {
    "text": "Core healthy. Sem incidentes. Nao houve rollback. Operacao estavel."
  }
}
JSON

SHA1="$(shasum -a 256 "${TASK1}" | awk '{print $1}')"
SHA2="$(shasum -a 256 "${TASK2}" | awk '{print $1}')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg task_quality "${TASK1}" \
  --arg task_speed "${TASK2}" \
  --arg sha_quality "${SHA1}" \
  --arg sha_speed "${SHA2}" \
  '{
    created_at: $created_at,
    seed: {
      quality_task_file: $task_quality,
      speed_task_file: $task_speed,
      quality_task_sha256: $sha_quality,
      speed_task_sha256: $sha_speed,
      objective: "provar roteamento inteligente por politica"
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 77 — Vision Policy Seed

## Tasks
- quality_task_file: ${TASK1}
- speed_task_file: ${TASK2}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] policy seed gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
