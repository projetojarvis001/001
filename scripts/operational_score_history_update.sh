#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
HISTORY_FILE="${OUT_DIR}/operational_score_history.json"
TMP_FILE="${OUT_DIR}/operational_score_history.tmp.json"

mkdir -p "${OUT_DIR}"

LATEST_SCORE_FILE="$(find "${OUT_DIR}" -maxdepth 1 -type f -name "operational_score_*.json" ! -name "operational_score_history.json" | sort | tail -n 1)"
if [ -z "${LATEST_SCORE_FILE}" ] || [ ! -f "${LATEST_SCORE_FILE}" ]; then
  echo "[ERRO] sem operational_score recente"
  exit 1
fi

if [ ! -f "${HISTORY_FILE}" ]; then
  echo '[]' > "${HISTORY_FILE}"
fi

jq empty "${HISTORY_FILE}" >/dev/null 2>&1 || echo '[]' > "${HISTORY_FILE}"

REF_DATE="$(jq -r '.created_at // ""' "${LATEST_SCORE_FILE}" | cut -c1-10)"
if [ -z "${REF_DATE}" ]; then
  echo "[ERRO] nao foi possivel determinar reference_day"
  exit 1
fi

jq \
  --slurpfile latest "${LATEST_SCORE_FILE}" \
  --arg ref_date "${REF_DATE}" \
  '
  map(select((.reference_day // "") != $ref_date)) +
  [
    {
      reference_day: $ref_date,
      created_at: ($latest[0].created_at // ""),
      final_score: ($latest[0].scoring.final_score // 0),
      grade: ($latest[0].scoring.grade // "N/A"),
      status: ($latest[0].scoring.status // "N/A"),
      total_penalty: ($latest[0].scoring.total_penalty // 0),
      risk_releases: ($latest[0].counters.risk_releases // 0),
      blocked_releases: ($latest[0].counters.blocked_releases // 0),
      rollback_releases: ($latest[0].counters.rollback_releases // 0),
      freeze_active: ($latest[0].context.freeze_active // false),
      stack_ok: ($latest[0].context.stack_ok // false),
      post_deploy_status: ($latest[0].context.post_deploy_status // "NOT_RUN"),
      go_live_status: ($latest[0].context.go_live_status // "UNKNOWN")
    }
  ]
  | sort_by(.reference_day)
  ' "${HISTORY_FILE}" > "${TMP_FILE}"

mv "${TMP_FILE}" "${HISTORY_FILE}"

echo "[OK] historico de score atualizado em ${HISTORY_FILE}"
cat "${HISTORY_FILE}" | jq .
