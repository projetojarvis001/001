#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/executive"
OUT_FILE="${OUT_DIR}/executive_ops_dashboard.json"

mkdir -p "${OUT_DIR}"
mkdir -p logs/state logs/history logs/readiness backups/postgres backups/redis backups/env backups/operational_state

STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{}')"
SLO_JSON="$(curl -fsS http://127.0.0.1:3000/stack/slo || echo '{}')"
HISTORY_JSON="$(curl -fsS http://127.0.0.1:3000/stack/history/compact || echo '{}')"
METRICS_JSON="$(curl -fsS http://127.0.0.1:3000/stack/metrics || echo '{}')"

READINESS_FILE="$(ls -1t logs/readiness/readiness_*.json 2>/dev/null | head -n 1 || true)"
CHAOS_FILE="$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)"
PG_FILE="$(ls -1t backups/postgres/*.sql.gz 2>/dev/null | head -n 1 || true)"
REDIS_FILE="$(ls -1t backups/redis/*.rdb 2>/dev/null | head -n 1 || true)"
OPS_FILE="$(ls -1t backups/operational_state/*.tar.gz 2>/dev/null | head -n 1 || true)"
ENV_FILE="$(ls -1t backups/env/*.bak 2>/dev/null | head -n 1 || true)"

ALERT_STATE_FILE="logs/state/alert_state.json"
AUTOHEAL_STATE_FILE="logs/state/auto_heal_state.json"

[ -f "${ALERT_STATE_FILE}" ] || echo '{}' > "${ALERT_STATE_FILE}"
[ -f "${AUTOHEAL_STATE_FILE}" ] || echo '{}' > "${AUTOHEAL_STATE_FILE}"

if [ -n "${READINESS_FILE}" ] && [ -f "${READINESS_FILE}" ]; then
  if [ -n "${RISK_FILE}" ] && [ -f "${RISK_FILE}" ]; then
    RISK_LEVEL=$(jq -r '.decision.risk_level // "UNKNOWN"' "${RISK_FILE}")
    GO_LIVE_STATUS=$(jq -r '.decision.go_live_status // "BLOQUEAR"' "${RISK_FILE}")
    CHANGE_POLICY=$(jq -r '.decision.change_policy // "FREEZE"' "${RISK_FILE}")
    OPERATOR_NOTE=$(jq -r '.decision.operator_note // "Sem nota operacional"' "${RISK_FILE}")
  else
    RISK_LEVEL="UNKNOWN"
    GO_LIVE_STATUS="BLOQUEAR"
    CHANGE_POLICY="FREEZE"
    OPERATOR_NOTE="Sem gate de risco. Nao liberar."
  fi

  jq -n \
    --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg readiness_file "${READINESS_FILE}" \
    --arg chaos_file "${CHAOS_FILE}" \
    --arg pg_file "${PG_FILE}" \
    --arg redis_file "${REDIS_FILE}" \
    --arg ops_file "${OPS_FILE}" \
    --arg env_file "${ENV_FILE}" \
    --argjson stack "${STACK_JSON}" \
    --argjson slo "${SLO_JSON}" \
    --argjson hist "${HISTORY_JSON}" \
    --argjson metrics "${METRICS_JSON}" \
    --slurpfile readiness "${READINESS_FILE}" \
    --slurpfile alert "${ALERT_STATE_FILE}" \
    --slurpfile autoheal "${AUTOHEAL_STATE_FILE}" '
    def safe_readiness: if ($readiness|length) > 0 then $readiness[0] else {} end;
    {
      generated_at: $generated_at,
      executive: {
        readiness: (safe_readiness.readiness // "UNKNOWN"),
        executive_recommendation: (safe_readiness.executive_recommendation // "REVISAR"),
        score: (safe_readiness.score // 0),
        max_score: (safe_readiness.max_score // 100),
        stack_ok: ($stack.ok // false),
        stack_status: (if ($stack.ok // false) then "saudavel" else "degradada" end),
        slo_today_percent: ($slo.availability_percent // 0),
        availability_7d_percent: ($hist.summary.average_availability_percent_7d // 0),
        downtime_7d_seconds: ($hist.summary.total_downtime_seconds_7d // 0),
        incidents_7d: ($hist.summary.total_incidents_7d // 0),
        trend_7d: ($hist.summary.trend_7d // "UNKNOWN"),
        executive_status: ($hist.summary.executive_status // "INDEFINIDO")
      },
      operations: {
        last_alert_key: ($alert[0].last_alert_key // ""),
        last_severity: ($alert[0].last_severity // ""),
        last_alert_at: ($alert[0].last_alert_at // 0),
        last_recovery_at: ($alert[0].last_recovery_at // 0),
        autoheal_last_action: ($autoheal[0].last_action // ""),
        autoheal_last_result: ($autoheal[0].last_result // ""),
        autoheal_last_diagnosis_kind: ($autoheal[0].last_diagnosis_kind // ""),
        autoheal_last_diagnosis_detail: ($autoheal[0].last_diagnosis_detail // ""),
        autoheal_postcheck_ok: ($autoheal[0].postcheck_ok // false)
      },
      artifacts: {
        readiness_file: $readiness_file,
        latest_chaos_suite: $chaos_file,
        latest_postgres_backup: $pg_file,
        latest_redis_backup: $redis_file,
        latest_operational_backup: $ops_file,
        latest_env_backup: $env_file
      },
      decision: {
        go_live_status:
          (if (safe_readiness.readiness // "") == "READY" and ($stack.ok // false) == true
           then "LIBERAR"
           elif ($stack.ok // false) == true
           then "LIBERAR_COM_RISCO"
           else "BLOQUEAR"
           end),
        operator_note:
          (if (safe_readiness.readiness // "") == "READY" and ($stack.ok // false) == true
           then "Stack pronta para operacao controlada."
           elif ($stack.ok // false) == true
           then "Stack de pe, mas ha pendencias de governanca."
           else "Nao liberar. Corrigir stack antes."
           end)
      }
    }' > "${OUT_FILE}"
else
  jq -n \
    --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg chaos_file "${CHAOS_FILE}" \
    --arg pg_file "${PG_FILE}" \
    --arg redis_file "${REDIS_FILE}" \
    --arg ops_file "${OPS_FILE}" \
    --arg env_file "${ENV_FILE}" \
    --argjson stack "${STACK_JSON}" \
    --argjson slo "${SLO_JSON}" \
    --argjson hist "${HISTORY_JSON}" \
    --slurpfile alert "${ALERT_STATE_FILE}" \
    --slurpfile autoheal "${AUTOHEAL_STATE_FILE}" '
    {
      generated_at: $generated_at,
      executive: {
        readiness: "UNKNOWN",
        executive_recommendation: "REVISAR",
        score: 0,
        max_score: 100,
        stack_ok: ($stack.ok // false),
        stack_status: (if ($stack.ok // false) then "saudavel" else "degradada" end),
        slo_today_percent: ($slo.availability_percent // 0),
        availability_7d_percent: ($hist.summary.average_availability_percent_7d // 0),
        downtime_7d_seconds: ($hist.summary.total_downtime_seconds_7d // 0),
        incidents_7d: ($hist.summary.total_incidents_7d // 0),
        trend_7d: ($hist.summary.trend_7d // "UNKNOWN"),
        executive_status: ($hist.summary.executive_status // "INDEFINIDO")
      },
      operations: {
        last_alert_key: ($alert[0].last_alert_key // ""),
        last_severity: ($alert[0].last_severity // ""),
        last_alert_at: ($alert[0].last_alert_at // 0),
        last_recovery_at: ($alert[0].last_recovery_at // 0),
        autoheal_last_action: ($autoheal[0].last_action // ""),
        autoheal_last_result: ($autoheal[0].last_result // ""),
        autoheal_last_diagnosis_kind: ($autoheal[0].last_diagnosis_kind // ""),
        autoheal_last_diagnosis_detail: ($autoheal[0].last_diagnosis_detail // ""),
        autoheal_postcheck_ok: ($autoheal[0].postcheck_ok // false)
      },
      artifacts: {
        readiness_file: "",
        latest_chaos_suite: $chaos_file,
        latest_postgres_backup: $pg_file,
        latest_redis_backup: $redis_file,
        latest_operational_backup: $ops_file,
        latest_env_backup: $env_file
      },
      decision: {
        go_live_status: (if ($stack.ok // false) then "LIBERAR_COM_RISCO" else "BLOQUEAR" end),
        operator_note: "Readiness ausente. Revisar antes de liberar."
      }
    }' > "${OUT_FILE}"
fi

echo "[OK] dashboard executivo gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
