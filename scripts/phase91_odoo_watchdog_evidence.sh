#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
SEED_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_seed_*.json 2>/dev/null | head -n 1 || true)"
WATCHDOG_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_run_*.json 2>/dev/null | head -n 1 || true)"
INFRA_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_infra_*.json 2>/dev/null | head -n 1 || true)"
ALERT_FILE="$(ls -1t logs/executive/phase91_odoo_alert_artifact_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase91_odoo_watchdog_evidence_${TS}.json"
OUT_MD="docs/generated/phase91_odoo_watchdog_evidence_${TS}.md"

WEB_OK="$(jq -r '.watchdog_run.web_ok' "${WATCHDOG_FILE}")"
AUTH_OK="$(jq -r '.watchdog_run.auth_ok' "${WATCHDOG_FILE}")"
ODOO_ACTIVE="$(jq -r '.infra_watchdog.odoo_active' "${INFRA_FILE}")"
NGINX_ACTIVE="$(jq -r '.infra_watchdog.nginx_active' "${INFRA_FILE}")"
PG_ACTIVE="$(jq -r '.infra_watchdog.pg_active' "${INFRA_FILE}")"
CHANNEL_READY="$(jq -r '.alert_artifact.channel_ready' "${ALERT_FILE}")"

FLOW_OK=false
if [ "${WEB_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ] && [ "${ODOO_ACTIVE}" = "true" ] && [ "${NGINX_ACTIVE}" = "true" ] && [ "${PG_ACTIVE}" = "true" ] && [ "${CHANNEL_READY}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg watchdog_file "${WATCHDOG_FILE}" \
  --arg infra_file "${INFRA_FILE}" \
  --arg alert_file "${ALERT_FILE}" \
  --argjson web_ok "${WEB_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson odoo_active "${ODOO_ACTIVE}" \
  --argjson nginx_active "${NGINX_ACTIVE}" \
  --argjson pg_active "${PG_ACTIVE}" \
  --argjson channel_ready "${CHANNEL_READY}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    watchdog_flow: {
      seed_file: $seed_file,
      watchdog_file: $watchdog_file,
      infra_file: $infra_file,
      alert_file: $alert_file,
      web_ok: $web_ok,
      auth_ok: $auth_ok,
      odoo_active: $odoo_active,
      nginx_active: $nginx_active,
      pg_active: $pg_active,
      channel_ready: $channel_ready,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 91 — ODOO Watchdog Evidence

## Flow
- web_ok: ${WEB_OK}
- auth_ok: ${AUTH_OK}
- odoo_active: ${ODOO_ACTIVE}
- nginx_active: ${NGINX_ACTIVE}
- pg_active: ${PG_ACTIVE}
- channel_ready: ${CHANNEL_READY}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] watchdog evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
