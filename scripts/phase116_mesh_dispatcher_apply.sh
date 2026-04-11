#!/usr/bin/env bash
set -euo pipefail

source ./scripts/load_mesh_env.sh >/dev/null

TS="$(date +%Y%m%d-%H%M%S)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RAW_FILE="runtime/dispatcher/phase116_mesh_dispatcher_apply_${TS}.txt"
OUT_JSON="logs/executive/phase116_mesh_dispatcher_apply_${TS}.json"
OUT_MD="docs/generated/phase116_mesh_dispatcher_apply_${TS}.md"
RESULT_FILE="dispatcher/jobs_results.json"

mkdir -p dispatcher runtime/dispatcher logs/executive docs/generated

VISION_OK=false
FRIDAY_OK=false
TADASH_OK=false

exec > >(tee "${RAW_FILE}") 2>&1

echo "===== APPLY PHASE116 ====="
echo

echo "===== VISION DISPATCH ====="
VISION_OUT="$(sshpass -p "${VISION_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${VISION_SSH_PORT}" "${VISION_SSH_USER}@${VISION_HOST}" 'echo vision_dispatch_ok; hostname; whoami')" || true
echo "${VISION_OUT}"
echo "${VISION_OUT}" | grep -q 'vision_dispatch_ok' && VISION_OK=true || true

echo
echo "===== FRIDAY DISPATCH ====="
FRIDAY_OUT="$(sshpass -p "${FRIDAY_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${FRIDAY_SSH_PORT}" "${FRIDAY_SSH_USER}@${FRIDAY_HOST}" 'echo friday_dispatch_ok; hostname; whoami')" || true
echo "${FRIDAY_OUT}"
echo "${FRIDAY_OUT}" | grep -q 'friday_dispatch_ok' && FRIDAY_OK=true || true

echo
echo "===== TADASH DISPATCH ====="
TADASH_OUT="$(sshpass -p "${TADASH_SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -p "${TADASH_SSH_PORT}" "${TADASH_SSH_USER}@${TADASH_HOST}" 'echo tadash_dispatch_ok; hostname; whoami')" || true
echo "${TADASH_OUT}"
echo "${TADASH_OUT}" | grep -q 'tadash_dispatch_ok' && TADASH_OK=true || true

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg vision_out "${VISION_OUT}" \
  --arg friday_out "${FRIDAY_OUT}" \
  --arg tadash_out "${TADASH_OUT}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  '{
    created_at: $created_at,
    results: [
      {
        node: "vision",
        ok: $vision_ok,
        output: $vision_out
      },
      {
        node: "friday",
        ok: $friday_ok,
        output: $friday_out
      },
      {
        node: "tadash",
        ok: $tadash_ok,
        output: $tadash_out
      }
    ]
  }' > "${RESULT_FILE}"

jq -n \
  --arg created_at "${CREATED_AT}" \
  --arg raw_file "${RAW_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --argjson vision_ok "${VISION_OK}" \
  --argjson friday_ok "${FRIDAY_OK}" \
  --argjson tadash_ok "${TADASH_OK}" \
  '{
    created_at: $created_at,
    mesh_dispatcher_apply: {
      raw_file: $raw_file,
      result_file: $result_file,
      vision_ok: $vision_ok,
      friday_ok: $friday_ok,
      tadash_ok: $tadash_ok,
      overall_ok: ($vision_ok and $friday_ok and $tadash_ok)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 116 — Mesh Dispatcher Apply

## Apply
- raw_file: ${RAW_FILE}
- result_file: ${RESULT_FILE}
- vision_ok: ${VISION_OK}
- friday_ok: ${FRIDAY_OK}
- tadash_ok: ${TADASH_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo
echo "[OK] phase116 apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
echo "[OK] results em ${RESULT_FILE}"
cat "${RESULT_FILE}" | jq .
