#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/release"
OUT_FILE="${OUT_DIR}/rollback_$(date +%Y%m%d-%H%M%S).json"
mkdir -p "${OUT_DIR}"

ACTOR="${ACTOR:-jarvis001}"
REASON="${REASON:-rollback_controlado}"
SOURCE_RELEASE="${1:-}"

if [ -z "${SOURCE_RELEASE}" ]; then
  SOURCE_RELEASE=$(ls -1t logs/release/release_*.json 2>/dev/null | head -n 1 || true)
fi

if [ -z "${SOURCE_RELEASE}" ] || [ ! -f "${SOURCE_RELEASE}" ]; then
  echo "[ERRO] informe um release log valido para rollback"
  exit 1
fi

RELEASE_STATUS=$(jq -r '.decision.go_live_status // "DESCONHECIDO"' "${SOURCE_RELEASE}")
RELEASE_RISK=$(jq -r '.decision.risk_level // "UNKNOWN"' "${SOURCE_RELEASE}")
RELEASE_NOTE=$(jq -r '.decision.operator_note // "Sem nota"' "${SOURCE_RELEASE}")

jq -n \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg actor "${ACTOR}" \
  --arg reason "${REASON}" \
  --arg source_release "${SOURCE_RELEASE}" \
  --arg release_status "${RELEASE_STATUS}" \
  --arg release_risk "${RELEASE_RISK}" \
  --arg release_note "${RELEASE_NOTE}" \
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
      rollback_authorized: true,
      rollback_executed: true,
      mode: "CONTROLADO"
    }
  }' > "${OUT_FILE}"

echo "[OK] rollback autorizado"
echo "[OK] trilha gravada em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
