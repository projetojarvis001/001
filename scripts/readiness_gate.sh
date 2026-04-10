#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUT_DIR="logs/readiness"
OUT_FILE="${OUT_DIR}/readiness_$(date +%Y%m%d-%H%M%S).json"

mkdir -p "${OUT_DIR}"

score=0
max_score=100

stack_ok=false
config_ok=false
chaos_ok=false
postgres_backup_ok=false
redis_backup_ok=false
ops_backup_ok=false
history_ok=false
slo_ok=false

latest_chaos="$(ls -1t logs/chaos_suite/chaos_suite_*.json 2>/dev/null | head -n 1 || true)"
latest_pg="$(ls -1t backups/postgres/*.sql.gz 2>/dev/null | head -n 1 || true)"
latest_redis="$(ls -1t backups/redis/*.rdb 2>/dev/null | head -n 1 || true)"
latest_ops="$(ls -1t backups/operational_state/*.tar.gz 2>/dev/null | head -n 1 || true)"

if curl -fsS http://127.0.0.1:3000/stack/health | jq -e '.ok == true' >/dev/null 2>&1; then
  stack_ok=true
  score=$((score + 25))
fi

if ./scripts/check_config_consistency.sh >/dev/null 2>&1; then
  config_ok=true
  score=$((score + 15))
fi

if [ -n "${latest_chaos}" ] && jq -e '.status == "PASS" and .fail == 0' "${latest_chaos}" >/dev/null 2>&1; then
  chaos_ok=true
  score=$((score + 20))
fi

if [ -n "${latest_pg}" ] && [ -f "${latest_pg}" ]; then
  postgres_backup_ok=true
  score=$((score + 10))
fi

if [ -n "${latest_redis}" ] && [ -f "${latest_redis}" ]; then
  redis_backup_ok=true
  score=$((score + 10))
fi

if [ -n "${latest_ops}" ] && [ -f "${latest_ops}" ]; then
  ops_backup_ok=true
  score=$((score + 10))
fi

if curl -fsS http://127.0.0.1:3000/stack/history | jq -e '.ok == true and .history != null' >/dev/null 2>&1; then
  history_ok=true
  score=$((score + 5))
fi

if curl -fsS http://127.0.0.1:3000/stack/slo | jq -e '.ok == true and .availability_percent != null' >/dev/null 2>&1; then
  slo_ok=true
  score=$((score + 5))
fi

readiness="NOT_READY"
executive_recommendation="NAO_LIBERAR"

if [ "${score}" -ge 90 ] && \
   [ "${stack_ok}" = true ] && \
   [ "${config_ok}" = true ] && \
   [ "${chaos_ok}" = true ]; then
  readiness="READY"
  executive_recommendation="LIBERAR"
elif [ "${score}" -ge 75 ]; then
  executive_recommendation="LIBERAR_COM_RESSALVAS"
fi

jq -n \
  --arg created_at "${STAMP}" \
  --arg readiness "${readiness}" \
  --arg executive_recommendation "${executive_recommendation}" \
  --argjson score "${score}" \
  --argjson max_score "${max_score}" \
  --arg latest_chaos "${latest_chaos}" \
  --arg latest_postgres_backup "${latest_pg}" \
  --arg latest_redis_backup "${latest_redis}" \
  --arg latest_operational_backup "${latest_ops}" \
  --argjson stack_ok "${stack_ok}" \
  --argjson config_ok "${config_ok}" \
  --argjson chaos_ok "${chaos_ok}" \
  --argjson postgres_backup_ok "${postgres_backup_ok}" \
  --argjson redis_backup_ok "${redis_backup_ok}" \
  --argjson ops_backup_ok "${ops_backup_ok}" \
  --argjson history_ok "${history_ok}" \
  --argjson slo_ok "${slo_ok}" \
  '{
    created_at: $created_at,
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
      operational_backup_ok: $ops_backup_ok,
      history_ok: $history_ok,
      slo_ok: $slo_ok
    },
    artifacts: {
      latest_chaos: $latest_chaos,
      latest_postgres_backup: $latest_postgres_backup,
      latest_redis_backup: $latest_redis_backup,
      latest_operational_backup: $latest_operational_backup
    }
  }' > "${OUT_FILE}"

echo "[OK] readiness gerado em ${OUT_FILE}"
cat "${OUT_FILE}" | jq .
