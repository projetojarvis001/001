#!/usr/bin/env bash
set -euo pipefail

source ./scripts/load_mesh_env.sh >/dev/null

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

QUEUE_FILE="scheduler/job_queue.json"
DLQ_FILE="scheduler/dead_letter_queue.json"
RESULT_FILE="scheduler/job_run_results.json"
RAW_FILE="runtime/scheduler/phase117_mesh_scheduler_run_${TS}.txt"
OUT_JSON="logs/executive/phase117_mesh_scheduler_run_${TS}.json"
OUT_MD="docs/generated/phase117_mesh_scheduler_run_${TS}.md"

mkdir -p scheduler runtime/scheduler logs/executive docs/generated

TMP_RESULTS="$(mktemp)"
TMP_QUEUE="$(mktemp)"
TMP_DLQ="$(mktemp)"

echo '[]' > "${TMP_RESULTS}"
cp "${QUEUE_FILE}" "${TMP_QUEUE}"
cp "${DLQ_FILE}" "${TMP_DLQ}"

exec > >(tee "${RAW_FILE}") 2>&1

echo "===== RUN PHASE117 ====="

for JOB_ID in $(jq -r '.jobs[] | select(.status=="pending") | .id' "${TMP_QUEUE}"); do
  NODE="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .node' "${TMP_QUEUE}")"
  HOST="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .host' "${TMP_QUEUE}")"
  SSH_PORT="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .ssh_port' "${TMP_QUEUE}")"
  USER_NAME="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .user' "${TMP_QUEUE}")"
  PASSWORD_ENV="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .password_env' "${TMP_QUEUE}")"
  COMMAND="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .command' "${TMP_QUEUE}")"
  MAX_RETRIES="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .max_retries' "${TMP_QUEUE}")"
  RETRY_COUNT="$(jq -r --arg id "${JOB_ID}" '.jobs[] | select(.id==$id) | .retry_count' "${TMP_QUEUE}")"

  PASSWORD="${!PASSWORD_ENV}"

  echo
  echo "===== JOB ${JOB_ID} / NODE ${NODE} ====="

  OUT="$(sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${SSH_PORT}" "${USER_NAME}@${HOST}" "${COMMAND}" 2>&1)" || true
  echo "${OUT}"

  OK=false
  case "${NODE}" in
    vision) echo "${OUT}" | grep -q 'sched_vision_ok' && OK=true || true ;;
    friday) echo "${OUT}" | grep -q 'sched_friday_ok' && OK=true || true ;;
    tadash) echo "${OUT}" | grep -q 'sched_tadash_ok' && OK=true || true ;;
  esac

  if [ "${OK}" = "true" ]; then
    jq --arg id "${JOB_ID}" '(.jobs[] | select(.id==$id) | .status) = "done"' "${TMP_QUEUE}" > "${TMP_QUEUE}.new" && mv "${TMP_QUEUE}.new" "${TMP_QUEUE}"
  else
    NEW_RETRY=$((RETRY_COUNT+1))
    if [ "${NEW_RETRY}" -ge "${MAX_RETRIES}" ]; then
      jq --arg id "${JOB_ID}" '(.jobs[] | select(.id==$id) | .status) = "dead"' "${TMP_QUEUE}" > "${TMP_QUEUE}.new" && mv "${TMP_QUEUE}.new" "${TMP_QUEUE}"
      jq --arg id "${JOB_ID}" '.jobs += [input.jobs[] | select(.id==$id)]' "${TMP_DLQ}" "${TMP_QUEUE}" > "${TMP_DLQ}.new" && mv "${TMP_DLQ}.new" "${TMP_DLQ}"
    else
      jq --arg id "${JOB_ID}" --argjson retry "${NEW_RETRY}" '(.jobs[] | select(.id==$id) | .retry_count) = $retry | (.jobs[] | select(.id==$id) | .status) = "retry"' "${TMP_QUEUE}" > "${TMP_QUEUE}.new" && mv "${TMP_QUEUE}.new" "${TMP_QUEUE}"
    fi
  fi

  jq \
    --arg job_id "${JOB_ID}" \
    --arg node "${NODE}" \
    --arg output "${OUT}" \
    --argjson ok "${OK}" \
    '. += [{"job_id":$job_id,"node":$node,"ok":$ok,"output":$output}]' \
    "${TMP_RESULTS}" > "${TMP_RESULTS}.new" && mv "${TMP_RESULTS}.new" "${TMP_RESULTS}"
done

mv "${TMP_QUEUE}" "${QUEUE_FILE}"
mv "${TMP_DLQ}" "${DLQ_FILE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --slurpfile results "${TMP_RESULTS}" \
  '{
    created_at: $created_at,
    results: $results[0]
  }' > "${RESULT_FILE}"

DONE_COUNT="$(jq '[.jobs[] | select(.status=="done")] | length' "${QUEUE_FILE}")"
RETRY_COUNT_TOTAL="$(jq '[.jobs[] | select(.status=="retry")] | length' "${QUEUE_FILE}")"
DEAD_COUNT="$(jq '[.jobs[] | select(.status=="dead")] | length' "${QUEUE_FILE}")"

OVERALL_OK=false
[ "${DONE_COUNT}" -eq 3 ] && OVERALL_OK=true || true

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --arg queue_file "${QUEUE_FILE}" \
  --arg dlq_file "${DLQ_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --argjson done_count "${DONE_COUNT}" \
  --argjson retry_count "${RETRY_COUNT_TOTAL}" \
  --argjson dead_count "${DEAD_COUNT}" \
  --argjson overall_ok "${OVERALL_OK}" \
  '{
    created_at: $created_at,
    mesh_scheduler_run: {
      raw_file: $raw_file,
      queue_file: $queue_file,
      dlq_file: $dlq_file,
      result_file: $result_file,
      done_count: $done_count,
      retry_count: $retry_count,
      dead_count: $dead_count,
      overall_ok: $overall_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 117 — Mesh Scheduler Run

## Run
- raw_file: ${RAW_FILE}
- queue_file: ${QUEUE_FILE}
- dlq_file: ${DLQ_FILE}
- result_file: ${RESULT_FILE}
- done_count: ${DONE_COUNT}
- retry_count: ${RETRY_COUNT_TOTAL}
- dead_count: ${DEAD_COUNT}
- overall_ok: ${OVERALL_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo
echo "[OK] phase117 run gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] queue final"
cat "${QUEUE_FILE}" | jq .
echo
echo "[OK] dlq final"
cat "${DLQ_FILE}" | jq .
echo
echo "[OK] results"
cat "${RESULT_FILE}" | jq .
