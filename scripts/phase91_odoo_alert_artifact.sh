#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
WATCHDOG_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_run_*.json 2>/dev/null | head -n 1 || true)"
INFRA_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_infra_*.json 2>/dev/null | head -n 1 || true)"
OUT_JSON="logs/executive/phase91_odoo_alert_artifact_${TS}.json"
OUT_MD="docs/generated/phase91_odoo_alert_artifact_${TS}.md"

WEB_OK="$(jq -r '.watchdog_run.web_ok' "${WATCHDOG_FILE}")"
RPC_OK="$(jq -r '.watchdog_run.rpc_ok' "${WATCHDOG_FILE}")"
AUTH_OK="$(jq -r '.watchdog_run.auth_ok' "${WATCHDOG_FILE}")"
ODOO_ACTIVE="$(jq -r '.infra_watchdog.odoo_active' "${INFRA_FILE}")"
NGINX_ACTIVE="$(jq -r '.infra_watchdog.nginx_active' "${INFRA_FILE}")"
PG_ACTIVE="$(jq -r '.infra_watchdog.pg_active' "${INFRA_FILE}")"

STATUS="GREEN"
[ "${WEB_OK}" != "true" ] && STATUS="RED" || true
[ "${RPC_OK}" != "true" ] && STATUS="RED" || true
[ "${AUTH_OK}" != "true" ] && STATUS="RED" || true
[ "${ODOO_ACTIVE}" != "true" ] && STATUS="RED" || true
[ "${NGINX_ACTIVE}" != "true" ] && STATUS="RED" || true
[ "${PG_ACTIVE}" != "true" ] && STATUS="RED" || true

ALERT_MESSAGE="OK: watchdog do ODOO operacional"
[ "${STATUS}" != "GREEN" ] && ALERT_MESSAGE="ALERTA: watchdog do ODOO detectou degradacao" || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg watchdog_file "${WATCHDOG_FILE}" \
  --arg infra_file "${INFRA_FILE}" \
  --arg status "${STATUS}" \
  --arg alert_message "${ALERT_MESSAGE}" \
  '{
    created_at: $created_at,
    alert_artifact: {
      watchdog_file: $watchdog_file,
      infra_file: $infra_file,
      status: $status,
      alert_message: $alert_message,
      channel_ready: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 91 — ODOO Alert Artifact

## Artifact
- watchdog_file: ${WATCHDOG_FILE}
- infra_file: ${INFRA_FILE}
- status: ${STATUS}
- alert_message: ${ALERT_MESSAGE}
- channel_ready: true

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] alert artifact gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
