#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
mkdir -p "${OUT_DIR}"

STAMP_LOCAL="$(date +%Y%m%d-%H%M%S)"
STAMP_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT_FILE="${OUT_DIR}/operational_risk_${STAMP_LOCAL}.json"

STRICT_FILE=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${STRICT_FILE}" ] || [ ! -f "${STRICT_FILE}" ]; then
  echo "[ERRO] readiness strict nao encontrado"
  exit 1
fi

HISTORY_JSON="$(curl -fsS http://127.0.0.1:3000/stack/history/compact || echo '{"ok":false}')"
SLO_JSON="$(curl -fsS http://127.0.0.1:3000/stack/slo || echo '{"ok":false}')"
METRICS_JSON="$(curl -fsS http://127.0.0.1:3000/stack/metrics || echo '{"ok":false}')"
STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{"ok":false}')"

STRICT_READY="$(jq -r '.readiness // "BLOCKED"' "${STRICT_FILE}")"
STRICT_SCORE="$(jq -r '.score // 0' "${STRICT_FILE}")"

STACK_OK="$(printf '%s' "${STACK_JSON}" | jq -r '.ok // false')"
SLO_OK="$(printf '%s' "${SLO_JSON}" | jq -r '.ok // false')"
SLO_STATUS="$(printf '%s' "${SLO_JSON}" | jq -r '.status // "red"')"
SLO_PERCENT="$(printf '%s' "${SLO_JSON}" | jq -r '.availability_percent // 0')"

EXEC_STATUS="$(printf '%s' "${HISTORY_JSON}" | jq -r '.summary.executive_status // "CRITICO"')"
TREND_7D="$(printf '%s' "${HISTORY_JSON}" | jq -r '.summary.trend_7d // "UNKNOWN"')"
INCIDENTS_7D="$(printf '%s' "${HISTORY_JSON}" | jq -r '.summary.total_incidents_7d // 0')"
DOWNTIME_7D="$(printf '%s' "${HISTORY_JSON}" | jq -r '.summary.total_downtime_seconds_7d // 0')"
AVG_AVAIL_7D="$(printf '%s' "${HISTORY_JSON}" | jq -r '.summary.average_availability_percent_7d // 0')"

AUTOHEAL_LAST_RESULT="$(printf '%s' "${METRICS_JSON}" | jq -r '.autoHeal.last_result // ""')"
AUTOHEAL_LAST_ACTION="$(printf '%s' "${METRICS_JSON}" | jq -r '.autoHeal.last_action // ""')"
AUTOHEAL_LAST_KIND="$(printf '%s' "${METRICS_JSON}" | jq -r '.autoHeal.last_diagnosis_kind // ""')"
AUTOHEAL_POSTCHECK_OK="$(printf '%s' "${METRICS_JSON}" | jq -r '.autoHeal.postcheck_ok // false')"

RISK_LEVEL="LOW"
GO_LIVE_STATUS="LIBERAR"
OPERATOR_NOTE="Stack pronta para operacao."
CHANGE_POLICY="OPEN"

REMOTE_DEP_RISK="false"
if [ "${AUTOHEAL_LAST_RESULT}" = "remote_dependency" ]; then
  REMOTE_DEP_RISK="true"
fi

if [ "${STRICT_READY}" != "READY" ] || [ "${STACK_OK}" != "true" ] || [ "${SLO_OK}" != "true" ]; then
  RISK_LEVEL="CRITICAL"
  GO_LIVE_STATUS="BLOQUEAR"
  CHANGE_POLICY="FREEZE"
  OPERATOR_NOTE="Gate estrito nao aprovado ou stack indisponivel."
else
  if [ "${EXEC_STATUS}" = "CRITICO" ]; then
    RISK_LEVEL="HIGH"
    GO_LIVE_STATUS="LIBERAR_COM_RISCO"
    CHANGE_POLICY="FREEZE"
    OPERATOR_NOTE="Stack viva, mas historico operacional critico. Liberar so operacao controlada."
  elif [ "${EXEC_STATUS}" = "ATENCAO" ]; then
    RISK_LEVEL="MEDIUM"
    GO_LIVE_STATUS="OPERAR_COM_CAUTELA"
    CHANGE_POLICY="CONTROLLED"
    OPERATOR_NOTE="Stack aprovada, com atencao operacional."
  fi

  if [ "${REMOTE_DEP_RISK}" = "true" ] && [ "${RISK_LEVEL}" = "LOW" ]; then
    RISK_LEVEL="MEDIUM"
    GO_LIVE_STATUS="OPERAR_COM_CAUTELA"
    CHANGE_POLICY="CONTROLLED"
    OPERATOR_NOTE="Dependencia remota foi ultimo fator de risco. Operar com cautela."
  fi

  if [ "${INCIDENTS_7D}" -ge 5 ] && [ "${RISK_LEVEL}" = "LOW" ]; then
    RISK_LEVEL="MEDIUM"
    GO_LIVE_STATUS="OPERAR_COM_CAUTELA"
    CHANGE_POLICY="CONTROLLED"
    OPERATOR_NOTE="Volume de incidentes recente pede cautela."
  fi

  if [ "${INCIDENTS_7D}" -ge 5 ] && [ "${RISK_LEVEL}" = "MEDIUM" ]; then
    RISK_LEVEL="HIGH"
    GO_LIVE_STATUS="LIBERAR_COM_RISCO"
    CHANGE_POLICY="FREEZE"
    OPERATOR_NOTE="Historico recente acima do limite de incidentes. Liberacao so com risco aceito."
  fi

  awk "BEGIN { exit !(${AVG_AVAIL_7D} < 99.9) }" && {
    if [ "${RISK_LEVEL}" = "LOW" ]; then
      RISK_LEVEL="MEDIUM"
      GO_LIVE_STATUS="OPERAR_COM_CAUTELA"
      CHANGE_POLICY="CONTROLLED"
      OPERATOR_NOTE="Disponibilidade media 7d abaixo da meta."
    fi
  }

  if [ "${SLO_STATUS}" = "red" ]; then
    RISK_LEVEL="HIGH"
    GO_LIVE_STATUS="LIBERAR_COM_RISCO"
    CHANGE_POLICY="FREEZE"
    OPERATOR_NOTE="SLO atual em vermelho."
  fi
fi

jq -n \
  --arg created_at "${STAMP_UTC}" \
  --arg strict_file "${STRICT_FILE}" \
  --arg strict_readiness "${STRICT_READY}" \
  --argjson strict_score "${STRICT_SCORE}" \
  --argjson stack_ok "${STACK_OK}" \
  --argjson slo_ok "${SLO_OK}" \
  --arg slo_status "${SLO_STATUS}" \
  --argjson slo_percent "${SLO_PERCENT}" \
  --arg exec_status "${EXEC_STATUS}" \
  --arg trend_7d "${TREND_7D}" \
  --argjson incidents_7d "${INCIDENTS_7D}" \
  --argjson downtime_7d "${DOWNTIME_7D}" \
  --argjson availability_7d_percent "${AVG_AVAIL_7D}" \
  --arg autoheal_last_result "${AUTOHEAL_LAST_RESULT}" \
  --arg autoheal_last_action "${AUTOHEAL_LAST_ACTION}" \
  --arg autoheal_last_kind "${AUTOHEAL_LAST_KIND}" \
  --argjson autoheal_postcheck_ok "${AUTOHEAL_POSTCHECK_OK}" \
  --argjson remote_dependency_risk "${REMOTE_DEP_RISK}" \
  --arg risk_level "${RISK_LEVEL}" \
  --arg go_live_status "${GO_LIVE_STATUS}" \
  --arg operator_note "${OPERATOR_NOTE}" \
  --arg change_policy "${CHANGE_POLICY}" \
  '{
    created_at: $created_at,
    source: {
      strict_file: $strict_file
    },
    health: {
      strict_readiness: $strict_readiness,
      strict_score: $strict_score,
      stack_ok: $stack_ok,
      slo_ok: $slo_ok,
      slo_status: $slo_status,
      slo_percent: $slo_percent
    },
    observability: {
      executive_status: $exec_status,
      trend_7d: $trend_7d,
      incidents_7d: $incidents_7d,
      downtime_7d: $downtime_7d,
      availability_7d_percent: $availability_7d_percent
    },
    operations: {
      autoheal_last_result: $autoheal_last_result,
      autoheal_last_action: $autoheal_last_action,
      autoheal_last_kind: $autoheal_last_kind,
      autoheal_postcheck_ok: $autoheal_postcheck_ok,
      remote_dependency_risk: $remote_dependency_risk
    },
    decision: {
      risk_level: $risk_level,
      go_live_status: $go_live_status,
      change_policy: $change_policy,
      operator_note: $operator_note
    }
  }' > "${OUT_FILE}"

echo "[OK] operational risk gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
