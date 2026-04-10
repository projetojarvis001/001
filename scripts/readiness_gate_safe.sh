#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

OUT_DIR="logs/readiness"
mkdir -p "${OUT_DIR}"

STAMP_LOCAL="$(date +%Y%m%d-%H%M%S)"
STAMP_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT_FILE="${OUT_DIR}/readiness_safe_${STAMP_LOCAL}.json"

LATEST_CHAOS="$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)"
LATEST_PG="$(ls -1t backups/postgres/*.sql.gz 2>/dev/null | head -n 1 || true)"
LATEST_REDIS="$(ls -1t backups/redis/*.rdb 2>/dev/null | head -n 1 || true)"
LATEST_OPS="$(ls -1t backups/operational_state/*.tar.gz 2>/dev/null | head -n 1 || true)"
LATEST_ENV="$(ls -1t backups/env/*.bak 2>/dev/null | head -n 1 || true)"

STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{"ok":false}')"
SLO_JSON="$(curl -fsS http://127.0.0.1:3000/stack/slo || echo '{"ok":false}')"
HISTORY_COMPACT_JSON="$(curl -fsS http://127.0.0.1:3000/stack/history/compact || echo '{"ok":false}')"
METRICS_JSON="$(curl -fsS http://127.0.0.1:3000/stack/metrics || echo '{"ok":false}')"

STACK_OK="$(printf '%s' "${STACK_JSON}" | jq -r '.ok // false')"

CONFIG_OK="false"
if ./scripts/check_config_consistency.sh >/tmp/readiness_safe_config.out 2>/tmp/readiness_safe_config.err; then
  CONFIG_OK="true"
fi

CHAOS_OK="false"
if [ -n "${LATEST_CHAOS}" ] && [ -f "${LATEST_CHAOS}" ]; then
  CHAOS_OK="$(jq -r '.status == "PASS"' "${LATEST_CHAOS}" 2>/dev/null || echo false)"
fi

PG_OK="false"
[ -n "${LATEST_PG}" ] && [ -f "${LATEST_PG}" ] && PG_OK="true"

REDIS_OK="false"
[ -n "${LATEST_REDIS}" ] && [ -f "${LATEST_REDIS}" ] && REDIS_OK="true"

OPS_OK="false"
[ -n "${LATEST_OPS}" ] && [ -f "${LATEST_OPS}" ] && OPS_OK="true"

ENV_OK="false"
[ -n "${LATEST_ENV}" ] && [ -f "${LATEST_ENV}" ] && ENV_OK="true"

HISTORY_OK="$(printf '%s' "${HISTORY_COMPACT_JSON}" | jq -r '.ok // false')"
SLO_OK="$(printf '%s' "${SLO_JSON}" | jq -r '.ok // false')"

SLO_STATUS="$(printf '%s' "${SLO_JSON}" | jq -r '.status // ""')"
SLO_PERCENT="$(printf '%s' "${SLO_JSON}" | jq -r '.availability_percent // 0')"

INCIDENTS_7D="$(printf '%s' "${HISTORY_COMPACT_JSON}" | jq -r '.summary.total_incidents_7d // 0')"
DOWNTIME_7D="$(printf '%s' "${HISTORY_COMPACT_JSON}" | jq -r '.summary.total_downtime_seconds_7d // 0')"
EXEC_STATUS="$(printf '%s' "${HISTORY_COMPACT_JSON}" | jq -r '.summary.executive_status // ""')"

SCORE=0
MAX_SCORE=100

[ "${STACK_OK}" = "true" ] && SCORE=$((SCORE + 20))
[ "${CONFIG_OK}" = "true" ] && SCORE=$((SCORE + 15))
[ "${CHAOS_OK}" = "true" ] && SCORE=$((SCORE + 15))
[ "${PG_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${REDIS_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${OPS_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${ENV_OK}" = "true" ] && SCORE=$((SCORE + 5))
[ "${HISTORY_OK}" = "true" ] && SCORE=$((SCORE + 5))
[ "${SLO_OK}" = "true" ] && SCORE=$((SCORE + 10))

READINESS="BLOCKED"
RECOMMENDATION="NAO_LIBERAR"

if [ "${STACK_OK}" = "true" ] \
  && [ "${CONFIG_OK}" = "true" ] \
  && [ "${CHAOS_OK}" = "true" ] \
  && [ "${PG_OK}" = "true" ] \
  && [ "${REDIS_OK}" = "true" ] \
  && [ "${OPS_OK}" = "true" ] \
  && [ "${ENV_OK}" = "true" ] \
  && [ "${HISTORY_OK}" = "true" ] \
  && [ "${SLO_OK}" = "true" ]; then
  READINESS="READY"
  RECOMMENDATION="LIBERAR"
fi

jq -n \
  --arg created_at "${STAMP_UTC}" \
  --arg readiness "${READINESS}" \
  --arg executive_recommendation "${RECOMMENDATION}" \
  --argjson score "${SCORE}" \
  --argjson max_score "${MAX_SCORE}" \
  --argjson stack_ok "${STACK_OK}" \
  --argjson config_ok "${CONFIG_OK}" \
  --argjson chaos_ok "${CHAOS_OK}" \
  --argjson postgres_backup_ok "${PG_OK}" \
  --argjson redis_backup_ok "${REDIS_OK}" \
  --argjson operational_backup_ok "${OPS_OK}" \
  --argjson env_backup_ok "${ENV_OK}" \
  --argjson history_ok "${HISTORY_OK}" \
  --argjson slo_ok "${SLO_OK}" \
  --arg slo_status "${SLO_STATUS}" \
  --arg slo_percent "${SLO_PERCENT}" \
  --arg incidents_7d "${INCIDENTS_7D}" \
  --arg downtime_7d "${DOWNTIME_7D}" \
  --arg executive_status "${EXEC_STATUS}" \
  --arg latest_chaos "${LATEST_CHAOS}" \
  --arg latest_postgres_backup "${LATEST_PG}" \
  --arg latest_redis_backup "${LATEST_REDIS}" \
  --arg latest_operational_backup "${LATEST_OPS}" \
  --arg latest_env_backup "${LATEST_ENV}" \
  '{
    created_at: $created_at,
    mode: "SAFE_NO_CHAOS",
    readiness: $readiness,
    executive_recommendation: $executive_recommendation,
    score: $score,
    max_score: $max_score,
    checks: {
      stack_ok: $stack_ok,
      config_ok: $config_ok,
      chaos_ok: $chaos_ok,
      postgres_backup_ok: $postgres_backup_ok,
      redis_backup_ok: $redis_backup_ok,
      operational_backup_ok: $operational_backup_ok,
      env_backup_ok: $env_backup_ok,
      history_ok: $history_ok,
      slo_ok: $slo_ok
    },
    observability: {
      slo_status: $slo_status,
      slo_percent: ($slo_percent | tonumber? // 0),
      incidents_7d: ($incidents_7d | tonumber? // 0),
      downtime_7d: ($downtime_7d | tonumber? // 0),
      executive_status: $executive_status
    },
    artifacts: {
      latest_chaos: $latest_chaos,
      latest_postgres_backup: $latest_postgres_backup,
      latest_redis_backup: $latest_redis_backup,
      latest_operational_backup: $latest_operational_backup,
      latest_env_backup: $latest_env_backup
    }
  }' > "${OUT_FILE}"

echo "[OK] readiness safe gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
