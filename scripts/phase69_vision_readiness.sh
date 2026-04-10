#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase69_vision_readiness_${TS}.json"
OUT_MD="docs/generated/phase69_vision_readiness_${TS}.md"

INVENTORY_FILE="$(ls -1t logs/executive/phase69_vision_inventory_*.json 2>/dev/null | head -n 1 || true)"

OLLAMA_BIN_OK="$(jq -r '.inventory.ollama_bin_ok // false' "${INVENTORY_FILE}" 2>/dev/null || echo false)"
REDIS_PRESENT=false
CORE_PRESENT=false
VISION_SCRIPT_PRESENT=false
LOGS_PRESENT=false
OLLAMA_LIST_OK=false

if jq -e '.inventory.redis_container != ""' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  REDIS_PRESENT=true
fi

if jq -e '.inventory.core_container != ""' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  CORE_PRESENT=true
fi

if jq -e '.inventory.script_count > 0' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  VISION_SCRIPT_PRESENT=true
fi

if jq -e '.inventory.log_count > 0' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  LOGS_PRESENT=true
fi

if [ "${OLLAMA_BIN_OK}" = "true" ]; then
  if ollama list >/tmp/phase69_ollama_list.out 2>/dev/null; then
    OLLAMA_LIST_OK=true
  fi
fi

READINESS_SCORE=0
[ "${REDIS_PRESENT}" = "true" ] && READINESS_SCORE=$((READINESS_SCORE + 20))
[ "${CORE_PRESENT}" = "true" ] && READINESS_SCORE=$((READINESS_SCORE + 20))
[ "${VISION_SCRIPT_PRESENT}" = "true" ] && READINESS_SCORE=$((READINESS_SCORE + 20))
[ "${LOGS_PRESENT}" = "true" ] && READINESS_SCORE=$((READINESS_SCORE + 20))
[ "${OLLAMA_LIST_OK}" = "true" ] && READINESS_SCORE=$((READINESS_SCORE + 20))

READY_FOR_PHASE70=false
if [ "${READINESS_SCORE}" -ge 60 ]; then
  READY_FOR_PHASE70=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg inventory_file "${INVENTORY_FILE}" \
  --argjson redis_present "${REDIS_PRESENT}" \
  --argjson core_present "${CORE_PRESENT}" \
  --argjson vision_script_present "${VISION_SCRIPT_PRESENT}" \
  --argjson logs_present "${LOGS_PRESENT}" \
  --argjson ollama_bin_ok "${OLLAMA_BIN_OK}" \
  --argjson ollama_list_ok "${OLLAMA_LIST_OK}" \
  --argjson readiness_score "${READINESS_SCORE}" \
  --argjson ready_for_phase70 "${READY_FOR_PHASE70}" \
  '{
    created_at: $created_at,
    readiness: {
      redis_present: $redis_present,
      core_present: $core_present,
      vision_script_present: $vision_script_present,
      logs_present: $logs_present,
      ollama_bin_ok: $ollama_bin_ok,
      ollama_list_ok: $ollama_list_ok,
      readiness_score: $readiness_score,
      ready_for_phase70: $ready_for_phase70
    },
    sources: {
      inventory_file: $inventory_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 69 — VISION Readiness

## Readiness
- redis_present: ${REDIS_PRESENT}
- core_present: ${CORE_PRESENT}
- vision_script_present: ${VISION_SCRIPT_PRESENT}
- logs_present: ${LOGS_PRESENT}
- ollama_bin_ok: ${OLLAMA_BIN_OK}
- ollama_list_ok: ${OLLAMA_LIST_OK}
- readiness_score: ${READINESS_SCORE}
- ready_for_phase70: ${READY_FOR_PHASE70}
MD

echo "[OK] vision readiness gerado em ${OUT_JSON}"
echo "[OK] markdown do readiness gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
