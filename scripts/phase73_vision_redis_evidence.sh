#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase73_vision_redis_evidence_${TS}.json"
OUT_MD="docs/generated/phase73_vision_redis_evidence_${TS}.md"

PUBLISH_FILE="$(ls -1t logs/executive/phase73_vision_redis_publish_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/outbox/redis_result_*.json 2>/dev/null | head -n 1 || true)"
LEDGER_FILE="runtime/vision/state/redis_processed_tasks.txt"

if [ -z "${PUBLISH_FILE}" ] || [ ! -f "${PUBLISH_FILE}" ]; then
  echo "[ERRO] publish file nao encontrado"
  exit 1
fi

if [ -z "${RESULT_FILE}" ] || [ ! -f "${RESULT_FILE}" ]; then
  echo "[ERRO] result file nao encontrado"
  exit 1
fi

TASK_FILE="$(jq -r '.publish.task_file // ""' "${PUBLISH_FILE}")"
TASK_ID="$(jq -r '.task_id // ""' "${TASK_FILE}")"
TASK_ID_OUT="$(jq -r '.task_id // ""' "${RESULT_FILE}")"
STATUS_OUT="$(jq -r '.status // ""' "${RESULT_FILE}")"
CLASSIFICATION_OUT="$(jq -r '.classification // ""' "${RESULT_FILE}")"
QUEUE_NAME="$(jq -r '.queue_name // ""' "${RESULT_FILE}")"
LEDGER_OK=false

if [ -f "${LEDGER_FILE}" ] && grep -Fxq "${TASK_ID}" "${LEDGER_FILE}"; then
  LEDGER_OK=true
fi

REDIS_FLOW_OK=false
if [ "${TASK_ID}" = "${TASK_ID_OUT}" ] && [ "${STATUS_OUT}" = "processed" ] && [ "${LEDGER_OK}" = "true" ]; then
  REDIS_FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg publish_file "${PUBLISH_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg task_id "${TASK_ID}" \
  --arg task_id_out "${TASK_ID_OUT}" \
  --arg status_out "${STATUS_OUT}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --arg queue_name "${QUEUE_NAME}" \
  --argjson ledger_ok "${LEDGER_OK}" \
  --argjson redis_flow_ok "${REDIS_FLOW_OK}" \
  '{
    created_at: $created_at,
    redis_flow: {
      publish_file: $publish_file,
      result_file: $result_file,
      task_id: $task_id,
      task_id_out: $task_id_out,
      status_out: $status_out,
      classification_out: $classification_out,
      queue_name: $queue_name,
      ledger_ok: $ledger_ok,
      redis_flow_ok: $redis_flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 73 — Vision Redis Evidence

## Redis Flow
- task_id: ${TASK_ID}
- task_id_out: ${TASK_ID_OUT}
- status_out: ${STATUS_OUT}
- classification_out: ${CLASSIFICATION_OUT}
- queue_name: ${QUEUE_NAME}
- ledger_ok: ${LEDGER_OK}
- redis_flow_ok: ${REDIS_FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] redis evidence gerado em ${OUT_JSON}"
echo "[OK] markdown do evidence gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
