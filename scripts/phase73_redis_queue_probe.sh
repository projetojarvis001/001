#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase73_redis_queue_probe_${TS}.json"
OUT_MD="docs/generated/phase73_redis_queue_probe_${TS}.md"

REDIS_CLI_OK=false
REDIS_PING_OK=false
REDIS_CONTAINER=""
AUTH_MODE="no_password"

if [ -n "${REDIS_PASSWORD:-}" ]; then
  AUTH_MODE="password"
fi

if command -v redis-cli >/dev/null 2>&1; then
  REDIS_CLI_OK=true
fi

REDIS_CONTAINER="$(docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}' | grep '^redis|' | head -n 1 || true)"

if [ -n "${REDIS_CONTAINER}" ]; then
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    if docker exec redis redis-cli -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG; then
      REDIS_PING_OK=true
    fi
  else
    if docker exec redis redis-cli ping 2>/dev/null | grep -q PONG; then
      REDIS_PING_OK=true
    fi
  fi
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg redis_container "${REDIS_CONTAINER}" \
  --arg auth_mode "${AUTH_MODE}" \
  --argjson redis_cli_ok "${REDIS_CLI_OK}" \
  --argjson redis_ping_ok "${REDIS_PING_OK}" \
  '{
    created_at: $created_at,
    redis_probe: {
      redis_container: $redis_container,
      auth_mode: $auth_mode,
      redis_cli_ok: $redis_cli_ok,
      redis_ping_ok: $redis_ping_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 73A — Redis Queue Probe

## Redis
- redis_container: ${REDIS_CONTAINER}
- auth_mode: ${AUTH_MODE}
- redis_cli_ok: ${REDIS_CLI_OK}
- redis_ping_ok: ${REDIS_PING_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] redis queue probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
