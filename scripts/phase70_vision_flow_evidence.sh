#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase70_vision_flow_evidence_${TS}.json"
OUT_MD="docs/generated/phase70_vision_flow_evidence_${TS}.md"

TASK_FILE="$(ls -1t runtime/vision/inbox/task_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/outbox/result_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${TASK_FILE}" ] || [ ! -f "${TASK_FILE}" ]; then
  echo "[ERRO] task file nao encontrado"
  exit 1
fi

if [ -z "${RESULT_FILE}" ] || [ ! -f "${RESULT_FILE}" ]; then
  echo "[ERRO] result file nao encontrado"
  exit 1
fi

TASK_ID_IN="$(jq -r '.task_id // ""' "${TASK_FILE}")"
TASK_ID_OUT="$(jq -r '.task_id // ""' "${RESULT_FILE}")"
STATUS_OUT="$(jq -r '.status // ""' "${RESULT_FILE}")"
CLASSIFICATION_OUT="$(jq -r '.classification // ""' "${RESULT_FILE}")"
CONFIDENCE_OUT="$(jq -r '.confidence // 0' "${RESULT_FILE}")"
SUMMARY_OUT="$(jq -r '.summary // ""' "${RESULT_FILE}")"

MATCH_OK=false
if [ "${TASK_ID_IN}" = "${TASK_ID_OUT}" ] && [ "${STATUS_OUT}" = "processed" ]; then
  MATCH_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg task_file "${TASK_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg task_id_in "${TASK_ID_IN}" \
  --arg task_id_out "${TASK_ID_OUT}" \
  --arg status_out "${STATUS_OUT}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --arg summary_out "${SUMMARY_OUT}" \
  --argjson confidence_out "${CONFIDENCE_OUT}" \
  --argjson match_ok "${MATCH_OK}" \
  '{
    created_at: $created_at,
    flow: {
      task_file: $task_file,
      result_file: $result_file,
      task_id_in: $task_id_in,
      task_id_out: $task_id_out,
      status_out: $status_out,
      classification_out: $classification_out,
      confidence_out: $confidence_out,
      summary_out: $summary_out,
      match_ok: $match_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 70 — Vision Flow Evidence

## Flow
- task_file: ${TASK_FILE}
- result_file: ${RESULT_FILE}
- task_id_in: ${TASK_ID_IN}
- task_id_out: ${TASK_ID_OUT}
- status_out: ${STATUS_OUT}
- classification_out: ${CLASSIFICATION_OUT}
- confidence_out: ${CONFIDENCE_OUT}
- match_ok: ${MATCH_OK}

## Summary
- ${SUMMARY_OUT}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] vision flow evidence gerado em ${OUT_JSON}"
echo "[OK] markdown do evidence gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
