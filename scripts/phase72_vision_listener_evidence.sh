#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase72_vision_listener_evidence_${TS}.json"
OUT_MD="docs/generated/phase72_vision_listener_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase72_vision_listener_seed_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/outbox/result_*.json 2>/dev/null | head -n 1 || true)"
LEDGER_FILE="runtime/vision/state/processed_tasks.txt"

if [ -z "${SEED_FILE}" ] || [ ! -f "${SEED_FILE}" ]; then
  echo "[ERRO] seed file nao encontrado"
  exit 1
fi

if [ -z "${RESULT_FILE}" ] || [ ! -f "${RESULT_FILE}" ]; then
  echo "[ERRO] result file nao encontrado"
  exit 1
fi

TASK_FILE="$(jq -r '.seed.task_file // ""' "${SEED_FILE}")"
TASK_ID_OUT="$(jq -r '.task_id // ""' "${RESULT_FILE}")"
STATUS_OUT="$(jq -r '.status // ""' "${RESULT_FILE}")"
CLASSIFICATION_OUT="$(jq -r '.classification // ""' "${RESULT_FILE}")"
LISTENER_MODE="$(jq -r '.listener_mode // ""' "${RESULT_FILE}")"
PROCESSED_IN_LEDGER=false

if [ -f "${LEDGER_FILE}" ] && grep -Fxq "${TASK_FILE}" "${LEDGER_FILE}"; then
  PROCESSED_IN_LEDGER=true
fi

AUTO_FLOW_OK=false
if [ "${STATUS_OUT}" = "processed" ] && [ "${LISTENER_MODE}" = "phase72_minimal_listener" ] && [ "${PROCESSED_IN_LEDGER}" = "true" ]; then
  AUTO_FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg task_file "${TASK_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg task_id_out "${TASK_ID_OUT}" \
  --arg status_out "${STATUS_OUT}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --arg listener_mode "${LISTENER_MODE}" \
  --argjson processed_in_ledger "${PROCESSED_IN_LEDGER}" \
  --argjson auto_flow_ok "${AUTO_FLOW_OK}" \
  '{
    created_at: $created_at,
    listener_flow: {
      seed_file: $seed_file,
      task_file: $task_file,
      result_file: $result_file,
      task_id_out: $task_id_out,
      status_out: $status_out,
      classification_out: $classification_out,
      listener_mode: $listener_mode,
      processed_in_ledger: $processed_in_ledger,
      auto_flow_ok: $auto_flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 72 — Vision Listener Evidence

## Listener Flow
- task_file: ${TASK_FILE}
- result_file: ${RESULT_FILE}
- task_id_out: ${TASK_ID_OUT}
- status_out: ${STATUS_OUT}
- classification_out: ${CLASSIFICATION_OUT}
- listener_mode: ${LISTENER_MODE}
- processed_in_ledger: ${PROCESSED_IN_LEDGER}
- auto_flow_ok: ${AUTO_FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] listener evidence gerado em ${OUT_JSON}"
echo "[OK] markdown do evidence gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
