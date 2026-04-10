#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase74_vision_batch_evidence_${TS}.json"
OUT_MD="docs/generated/phase74_vision_batch_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase74_vision_batch_seed_*.json 2>/dev/null | head -n 1 || true)"
LEDGER_FILE="runtime/vision/state/redis_processed_tasks.txt"

TASK1="$(jq -r '.batch_seed.tasks[0] // ""' "${SEED_FILE}")"
TASK2="$(jq -r '.batch_seed.tasks[1] // ""' "${SEED_FILE}")"
TASK3="$(jq -r '.batch_seed.tasks[2] // ""' "${SEED_FILE}")"

ID1="$(jq -r '.task_id // ""' "${TASK1}")"
ID2="$(jq -r '.task_id // ""' "${TASK2}")"
ID3="$(jq -r '.task_id // ""' "${TASK3}")"

R1="runtime/vision/outbox/redis_result_${ID1}.json"
R2="runtime/vision/outbox/redis_result_${ID2}.json"
R3="runtime/vision/outbox/redis_result_${ID3}.json"

OK1=false
OK2=false
OK3=false
LEDGER_OK=false
BATCH_FLOW_OK=false

[ -f "${R1}" ] && OK1=true
[ -f "${R2}" ] && OK2=true
[ -f "${R3}" ] && OK3=true

if [ -f "${LEDGER_FILE}" ] \
  && grep -Fxq "${ID1}" "${LEDGER_FILE}" \
  && grep -Fxq "${ID2}" "${LEDGER_FILE}" \
  && grep -Fxq "${ID3}" "${LEDGER_FILE}"; then
  LEDGER_OK=true
fi

if [ "${OK1}" = "true" ] && [ "${OK2}" = "true" ] && [ "${OK3}" = "true" ] && [ "${LEDGER_OK}" = "true" ]; then
  BATCH_FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg id1 "${ID1}" \
  --arg id2 "${ID2}" \
  --arg id3 "${ID3}" \
  --argjson ok1 "${OK1}" \
  --argjson ok2 "${OK2}" \
  --argjson ok3 "${OK3}" \
  --argjson ledger_ok "${LEDGER_OK}" \
  --argjson batch_flow_ok "${BATCH_FLOW_OK}" \
  '{
    created_at: $created_at,
    batch_flow: {
      seed_file: $seed_file,
      task_ids: [$id1, $id2, $id3],
      result_ok: {
        first: $ok1,
        second: $ok2,
        third: $ok3
      },
      ledger_ok: $ledger_ok,
      batch_flow_ok: $batch_flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 74 — Vision Batch Evidence

## Batch flow
- id1: ${ID1}
- id2: ${ID2}
- id3: ${ID3}
- ledger_ok: ${LEDGER_OK}
- batch_flow_ok: ${BATCH_FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] batch evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
