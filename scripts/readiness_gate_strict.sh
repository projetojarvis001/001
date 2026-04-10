#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

. ./scripts/lib_timestamp.sh

OUT_DIR="logs/readiness"
mkdir -p "${OUT_DIR}"

STAMP_LOCAL="$(date +%Y%m%d-%H%M%S)"
STAMP_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT_FILE="${OUT_DIR}/readiness_strict_${STAMP_LOCAL}.json"

CHAOS_MAX_AGE_SECONDS=$((24 * 3600))
BACKUP_MAX_AGE_SECONDS=$((12 * 3600))

LATEST_CHAOS="$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)"
LATEST_PG="$(ls -1t backups/postgres/*.sql.gz 2>/dev/null | head -n 1 || true)"
LATEST_REDIS="$(ls -1t backups/redis/*.rdb 2>/dev/null | head -n 1 || true)"
LATEST_OPS="$(ls -1t backups/operational_state/*.tar.gz 2>/dev/null | head -n 1 || true)"
LATEST_ENV="$(ls -1t backups/env/*.bak 2>/dev/null | head -n 1 || true)"

STACK_JSON="$(curl -fsS http://127.0.0.1:3000/stack/health || echo '{"ok":false}')"
SLO_JSON="$(curl -fsS http://127.0.0.1:3000/stack/slo || echo '{"ok":false}')"
HISTORY_COMPACT_JSON="$(curl -fsS http://127.0.0.1:3000/stack/history/compact || echo '{"ok":false}')"

STACK_OK="$(printf '%s' "${STACK_JSON}" | jq -r '.ok // false')"

CONFIG_OK="false"
if ./scripts/check_config_consistency.sh >/tmp/readiness_strict_config.out 2>/tmp/readiness_strict_config.err; then
  CONFIG_OK="true"
fi

CHAOS_JSON_OK="false"
if [ -n "${LATEST_CHAOS}" ] && [ -f "${LATEST_CHAOS}" ]; then
  CHAOS_JSON_OK="$(jq -r '.status == "PASS"' "${LATEST_CHAOS}" 2>/dev/null || echo false)"
fi

CHAOS_AGE=999999999
if [ -n "${LATEST_CHAOS}" ] && [ -f "${LATEST_CHAOS}" ]; then
  CHAOS_CREATED_AT="$(jq -r '.created_at // ""' "${LATEST_CHAOS}" 2>/dev/null || true)"
  CHAOS_EPOCH="$(iso_to_epoch_macos "${CHAOS_CREATED_AT}")"
  CHAOS_AGE="$(age_seconds_from_epoch "${CHAOS_EPOCH}")"
fi

CHAOS_FRESH_OK="false"
if [ "${CHAOS_AGE}" -le "${CHAOS_MAX_AGE_SECONDS}" ]; then
  CHAOS_FRESH_OK="true"
fi

CHAOS_OK="false"
if [ "${CHAOS_JSON_OK}" = "true" ] && [ "${CHAOS_FRESH_OK}" = "true" ]; then
  CHAOS_OK="true"
fi

pg_age=999999999
redis_age=999999999
ops_age=999999999
env_age=999999999

[ -n "${LATEST_PG}" ] && [ -f "${LATEST_PG}" ] && pg_age="$(age_seconds_from_epoch "$(file_epoch_macos "${LATEST_PG}")")"
[ -n "${LATEST_REDIS}" ] && [ -f "${LATEST_REDIS}" ] && redis_age="$(age_seconds_from_epoch "$(file_epoch_macos "${LATEST_REDIS}")")"
[ -n "${LATEST_OPS}" ] && [ -f "${LATEST_OPS}" ] && ops_age="$(age_seconds_from_epoch "$(file_epoch_macos "${LATEST_OPS}")")"
[ -n "${LATEST_ENV}" ] && [ -f "${LATEST_ENV}" ] && env_age="$(age_seconds_from_epoch "$(file_epoch_macos "${LATEST_ENV}")")"

PG_OK="false"
REDIS_OK="false"
OPS_OK="false"
ENV_OK="false"

[ -n "${LATEST_PG}" ] && [ -f "${LATEST_PG}" ] && [ "${pg_age}" -le "${BACKUP_MAX_AGE_SECONDS}" ] && PG_OK="true"
[ -n "${LATEST_REDIS}" ] && [ -f "${LATEST_REDIS}" ] && [ "${redis_age}" -le "${BACKUP_MAX_AGE_SECONDS}" ] && REDIS_OK="true"
[ -n "${LATEST_OPS}" ] && [ -f "${LATEST_OPS}" ] && [ "${ops_age}" -le "${BACKUP_MAX_AGE_SECONDS}" ] && OPS_OK="true"
[ -n "${LATEST_ENV}" ] && [ -f "${LATEST_ENV}" ] && [ "${env_age}" -le "${BACKUP_MAX_AGE_SECONDS}" ] && ENV_OK="true"

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
[ "${CHAOS_OK}" = "true" ] && SCORE=$((SCORE + 20))
[ "${PG_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${REDIS_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${OPS_OK}" = "true" ] && SCORE=$((SCORE + 10))
[ "${ENV_OK}" = "true" ] && SCORE=$((SCORE + 5))
[ "${HISTORY_OK}" = "true" ] && SCORE=$((SCORE + 5))
[ "${SLO_OK}" = "true" ] && SCORE=$((SCORE + 5))

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
  --arg mode "STRICT_FRESHNESS_POLICY" \
  --arg readiness "${READINESS}" \
  --arg executive_recommendation "${RECOMMENDATION}" \
  --argjson score "${SCORE}" \
  --argjson max_score "${MAX_SCORE}" \
  --argjson stack_ok "${STACK_OK}" \
  --argjson config_ok "${CONFIG_OK}" \
  --argjson chaos_ok "${CHAOS_OK}" \
  --argjson chaos_json_ok "${CHAOS_JSON_OK}" \
  --argjson chaos_fresh_ok "${CHAOS_FRESH_OK}" \
  --argjson postgres_backup_ok "${PG_OK}" \
  --argjson redis_backup_ok "${REDIS_OK}" \
  --argjson operational_backup_ok "${OPS_OK}" \
  --argjson env_backup_ok "${ENV_OK}" \
  --argjson history_ok "${HISTORY_OK}" \
  --argjson slo_ok "${SLO_OK}" \
  --argjson chaos_age_seconds "${CHAOS_AGE}" \
  --argjson postgres_age_seconds "${pg_age}" \
  --argjson redis_age_seconds "${redis_age}" \
  --argjson operational_age_seconds "${ops_age}" \
  --argjson env_age_seconds "${env_age}" \
  --argjson chaos_max_age_seconds "${CHAOS_MAX_AGE_SECONDS}" \
  --argjson backup_max_age_seconds "${BACKUP_MAX_AGE_SECONDS}" \
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
    mode: $mode,
    readiness: $readiness,
    executive_recommendation: $executive_recommendation,
    score: $score,
    max_score: $max_score,
    checks: {
      stack_ok: $stack_ok,
      config_ok: $config_ok,
      chaos_ok: $chaos_ok,
      chaos_json_ok: $chaos_json_ok,
      chaos_fresh_ok: $chaos_fresh_ok,
      postgres_backup_ok: $postgres_backup_ok,
      redis_backup_ok: $redis_backup_ok,
      operational_backup_ok: $operational_backup_ok,
      env_backup_ok: $env_backup_ok,
      history_ok: $history_ok,
      slo_ok: $slo_ok
    },
    freshness_policy: {
      chaos_max_age_seconds: $chaos_max_age_seconds,
      backup_max_age_seconds: $backup_max_age_seconds
    },
    freshness: {
      chaos_age_seconds: $chaos_age_seconds,
      postgres_age_seconds: $postgres_age_seconds,
      redis_age_seconds: $redis_age_seconds,
      operational_age_seconds: $operational_age_seconds,
      env_age_seconds: $env_age_seconds
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

echo "[OK] readiness strict gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
