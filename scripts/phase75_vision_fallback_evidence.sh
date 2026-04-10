#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase75_vision_fallback_evidence_${TS}.json"
OUT_MD="docs/generated/phase75_vision_fallback_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase75_vision_fallback_seed_*.json 2>/dev/null | head -n 1 || true)"
RESULT_FILE="$(ls -1t runtime/vision/fallback/out/fallback_result_*.json 2>/dev/null | head -n 1 || true)"
LEDGER_FILE="runtime/vision/fallback/state/fallback_processed.txt"

TASK_FILE="$(jq -r '.seed.task_file // ""' "${SEED_FILE}")"
TASK_ID="$(jq -r '.task_id // ""' "${TASK_FILE}")"
TASK_ID_OUT="$(jq -r '.task_id // ""' "${RESULT_FILE}")"
STATUS_OUT="$(jq -r '.status // ""' "${RESULT_FILE}")"
CLASSIFICATION_OUT="$(jq -r '.classification // ""' "${RESULT_FILE}")"
FALLBACK_USED="$(jq -r '.routing_result.fallback_used // false' "${RESULT_FILE}")"
PRIMARY_OK="$(jq -r '.routing_result.primary_ok // false' "${RESULT_FILE}")"
USED_MODEL="$(jq -r '.routing_result.used_model // ""' "${RESULT_FILE}")"

LEDGER_OK=false
FLOW_OK=false

if [ -f "${LEDGER_FILE}" ] && grep -Fxq "${TASK_ID}" "${LEDGER_FILE}"; then
  LEDGER_OK=true
fi

if [ "${TASK_ID}" = "${TASK_ID_OUT}" ] && [ "${STATUS_OUT}" = "processed" ] && [ "${FALLBACK_USED}" = "true" ] && [ "${LEDGER_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --arg task_id "${TASK_ID}" \
  --arg task_id_out "${TASK_ID_OUT}" \
  --arg status_out "${STATUS_OUT}" \
  --arg classification_out "${CLASSIFICATION_OUT}" \
  --arg used_model "${USED_MODEL}" \
  --argjson fallback_used "${FALLBACK_USED}" \
  --argjson primary_ok "${PRIMARY_OK}" \
  --argjson ledger_ok "${LEDGER_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    fallback_flow: {
      seed_file: $seed_file,
      result_file: $result_file,
      task_id: $task_id,
      task_id_out: $task_id_out,
      status_out: $status_out,
      classification_out: $classification_out,
      used_model: $used_model,
      fallback_used: $fallback_used,
      primary_ok: $primary_ok,
      ledger_ok: $ledger_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 75 — Vision Fallback Evidence

## Flow
- task_id: ${TASK_ID}
- task_id_out: ${TASK_ID_OUT}
- status_out: ${STATUS_OUT}
- classification_out: ${CLASSIFICATION_OUT}
- used_model: ${USED_MODEL}
- fallback_used: ${FALLBACK_USED}
- primary_ok: ${PRIMARY_OK}
- ledger_ok: ${LEDGER_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] fallback evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
