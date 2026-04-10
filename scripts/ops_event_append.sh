#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

EVENT_TYPE="${1:-}"
SOURCE_FILE="${2:-}"

OUT_DIR="logs/ops"
LEDGER_FILE="${OUT_DIR}/ops_event_ledger.jsonl"

mkdir -p "${OUT_DIR}"

if [ -z "${EVENT_TYPE}" ]; then
  echo "[ERRO] informe o tipo do evento"
  exit 1
fi

if [ -z "${SOURCE_FILE}" ] || [ ! -f "${SOURCE_FILE}" ]; then
  echo "[ERRO] informe um source_file valido"
  exit 1
fi

ACTOR="$(jq -r '.actor // .release_identity.actor // "system"' "${SOURCE_FILE}" 2>/dev/null || echo system)"
REASON="$(jq -r '.reason // .release_identity.reason // ""' "${SOURCE_FILE}" 2>/dev/null || echo "")"
FINAL_STATUS="$(jq -r '.result.final_status // .result.status // .decision.go_live_status // ""' "${SOURCE_FILE}" 2>/dev/null || echo "")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg event_type "${EVENT_TYPE}" \
  --arg source_file "${SOURCE_FILE}" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg final_status "${FINAL_STATUS}" \
  '{
    created_at: $created_at,
    event_type: $event_type,
    source_file: $source_file,
    actor: $actor,
    reason: $reason,
    final_status: $final_status
  }' >> "${LEDGER_FILE}"

echo "[OK] evento registrado em ${LEDGER_FILE}"
tail -n 1 "${LEDGER_FILE}" | jq .
