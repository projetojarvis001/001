#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

SOURCE_RELEASE="${1:-}"

if [ -z "${SOURCE_RELEASE}" ]; then
  SOURCE_RELEASE="$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${SOURCE_RELEASE}" ] || [ ! -f "${SOURCE_RELEASE}" ]; then
  echo "[ERRO] informe um release log valido"
  exit 1
fi

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/auto_rollback_$(date +%Y%m%d-%H%M%S).json"
mkdir -p "${OUT_DIR}"

ACTOR="${ACTOR:-auto_rollback}"
REASON="${REASON:-post_deploy_fail}"

RELEASE_STATUS="$(jq -r '.decision.go_live_status // "UNKNOWN"' "${SOURCE_RELEASE}")"
RELEASE_RISK="$(jq -r '.decision.risk_level // "UNKNOWN"' "${SOURCE_RELEASE}")"
RELEASE_NOTE="$(jq -r '.decision.operator_note // ""' "${SOURCE_RELEASE}")"

ROLLBACK_EXECUTED=false
ROLLBACK_FILE=""
FINAL_STATUS="ROLLBACK_FALHOU"
FINAL_NOTE="Rollback automatico falhou."

if ACTOR="${ACTOR}" REASON="${REASON}" ./scripts/rollback_controlled.sh "${SOURCE_RELEASE}"; then
  ROLLBACK_FILE="$(ls -1t logs/release/rollback_*.json 2>/dev/null | head -n 1 || true)"
  if [ -n "${ROLLBACK_FILE}" ] && [ -f "${ROLLBACK_FILE}" ]; then
    ROLLBACK_EXECUTED=true
    FINAL_STATUS="ROLLBACK_EXECUTADO"
    FINAL_NOTE="Rollback automatico executado apos falha no post-deploy."
  fi
fi

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg source_release "${SOURCE_RELEASE}" \
  --arg release_status "${RELEASE_STATUS}" \
  --arg release_risk "${RELEASE_RISK}" \
  --arg release_note "${RELEASE_NOTE}" \
  --arg rollback_file "${ROLLBACK_FILE}" \
  --arg final_status "${FINAL_STATUS}" \
  --arg final_note "${FINAL_NOTE}" \
  --argjson rollback_executed "${ROLLBACK_EXECUTED}" \
  '{
    created_at: $created_at,
    actor: $actor,
    reason: $reason,
    source: {
      release_file: $source_release,
      go_live_status: $release_status,
      risk_level: $release_risk,
      operator_note: $release_note
    },
    result: {
      rollback_executed: $rollback_executed,
      rollback_file: $rollback_file,
      final_status: $final_status,
      final_note: $final_note
    }
  }' > "${OUT_FILE}"

echo "[OK] auto rollback processado"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .

if [ "${ROLLBACK_EXECUTED}" = "true" ]; then
  exit 0
fi

exit 1
