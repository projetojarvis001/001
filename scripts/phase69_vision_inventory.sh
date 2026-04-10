#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase69_vision_inventory_${TS}.json"
OUT_MD="docs/generated/phase69_vision_inventory_${TS}.md"
TMP_SCRIPTS="runtime/phase69_vision_scripts_${TS}.txt"

grep -RliE 'vision|ollama|model_registry|listener|redis|pubsub|llm' scripts 2>/dev/null | sort > "${TMP_SCRIPTS}" || true

SCRIPT_COUNT="$(wc -l < "${TMP_SCRIPTS}" | tr -d ' ')"
SCRIPT_LIST_JSON="$(jq -R -s 'split("\n") | map(select(length > 0))' "${TMP_SCRIPTS}")"

OLLAMA_BIN_OK=false
if command -v ollama >/dev/null 2>&1; then
  OLLAMA_BIN_OK=true
fi

REDIS_CONTAINER="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep '^redis|' | head -n 1 || true)"
CORE_CONTAINER="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-jarvis-core-1' | head -n 1 || true)"
POSTGRES_CONTAINER="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | grep 'jarvis-postgres-1' | head -n 1 || true)"

OLLAMA_PROCESS="$(ps aux | grep -i '[o]llama' | head -n 1 || true)"
VISION_PROCESS="$(ps aux | grep -Ei '[v]ision|[l]istener|[m]odel_registry' | head -n 3 || true)"

LOG_CANDIDATES="$(find logs -type f \( -iname '*vision*' -o -iname '*model*' -o -iname '*ollama*' \) 2>/dev/null | sort | tail -n 20 || true)"
LOG_COUNT="$(printf '%s\n' "${LOG_CANDIDATES}" | sed '/^$/d' | wc -l | tr -d ' ')"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson script_count "${SCRIPT_COUNT}" \
  --argjson scripts "${SCRIPT_LIST_JSON}" \
  --arg redis_container "${REDIS_CONTAINER}" \
  --arg core_container "${CORE_CONTAINER}" \
  --arg postgres_container "${POSTGRES_CONTAINER}" \
  --arg ollama_process "${OLLAMA_PROCESS}" \
  --arg vision_process "${VISION_PROCESS}" \
  --arg log_candidates "${LOG_CANDIDATES}" \
  --argjson log_count "${LOG_COUNT}" \
  --argjson ollama_bin_ok "${OLLAMA_BIN_OK}" \
  '{
    created_at: $created_at,
    inventory: {
      script_count: $script_count,
      scripts: $scripts,
      redis_container: $redis_container,
      core_container: $core_container,
      postgres_container: $postgres_container,
      ollama_bin_ok: $ollama_bin_ok,
      ollama_process: $ollama_process,
      vision_process: $vision_process,
      log_count: $log_count,
      log_candidates: $log_candidates
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 69 — VISION Inventory

## Scripts relacionados
- total: ${SCRIPT_COUNT}

## Runtime
- redis_container: ${REDIS_CONTAINER}
- core_container: ${CORE_CONTAINER}
- postgres_container: ${POSTGRES_CONTAINER}
- ollama_bin_ok: ${OLLAMA_BIN_OK}

## Processos
- ollama_process: ${OLLAMA_PROCESS}
- vision_process: ${VISION_PROCESS}

## Logs
- log_count: ${LOG_COUNT}
MD

echo "[OK] vision inventory gerado em ${OUT_JSON}"
echo "[OK] markdown do inventory gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
