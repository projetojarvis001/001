#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase78_vision_memory_evidence_${TS}.json"
OUT_MD="docs/generated/phase78_vision_memory_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase78_vision_memory_seed_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/memory/out/memory_result_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${SEED_FILE}" ] || [ -z "${RESULT_FILE}" ]; then
  echo "[ERRO] seed ou result file nao encontrado"
  exit 1
fi

TASK_FILE="$(jq -r '.seed.task_file // ""' "${SEED_FILE}")"
TASK_ID="$(jq -r '.task_id // ""' "${RESULT_FILE}")"
STATUS_OUT="$(jq -r '.status // ""' "${RESULT_FILE}")"
CLASSIFICATION_OUT="$(jq -r '.classification // ""' "${RESULT_FILE}")"
MEMORY_EVENTS_USED="$(jq -r '.memory_events_used // 0' "${RESULT_FILE}")"

FLOW_OK=false
if [ "${STATUS_OUT}" = "processed" ] && [ "${MEMORY_EVENTS_USED}" -ge 2 ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg task_file "${TASK_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg task_id "${TASK_ID}" \
  --arg status_out "${STATUS_OUT}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --argjson memory_events_used "${MEMORY_EVENTS_USED}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    memory_flow: {
      seed_file: $seed_file,
      task_file: $task_file,
      result_file: $result_file,
      task_id: $task_id,
      status_out: $status_out,
      classification_out: $classification_out,
      memory_events_used: $memory_events_used,
      memory_flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 78 — Vision Memory Evidence

## Flow
- task_file: ${TASK_FILE}
- result_file: ${RESULT_FILE}
- task_id: ${TASK_ID}
- status_out: ${STATUS_OUT}
- classification_out: ${CLASSIFICATION_OUT}
- memory_events_used: ${MEMORY_EVENTS_USED}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] memory evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
