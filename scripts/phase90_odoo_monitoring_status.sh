#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase90_odoo_monitoring_status_${TS}.json"
OUT_MD="docs/generated/phase90_odoo_monitoring_status_${TS}.md"

WEB_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_web_probe_*.json 2>/dev/null | head -n 1 || true)"
RPC_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_rpc_probe_*.json 2>/dev/null | head -n 1 || true)"
INFRA_FILE="$(ls -1t logs/executive/phase90_odoo_monitoring_infra_probe_*.json 2>/dev/null | head -n 1 || true)"

WEB_OK="$(jq -r '.web_probe.http_ok and .web_probe.login_page_ok' "${WEB_FILE}")"
RPC_OK="$(jq -r '.rpc_probe.xmlrpc_common_ok and .rpc_probe.auth_ok' "${RPC_FILE}")"
ODOO_ACTIVE="$(jq -r '.infra_probe.odoo_active' "${INFRA_FILE}")"
NGINX_ACTIVE="$(jq -r '.infra_probe.nginx_active' "${INFRA_FILE}")"
PG_ACTIVE="$(jq -r '.infra_probe.pg_active' "${INFRA_FILE}")"
HAS_NGINX_8069="$(jq -r '.infra_probe.has_nginx_8069' "${INFRA_FILE}")"
HAS_ODOO_8070="$(jq -r '.infra_probe.has_odoo_8070' "${INFRA_FILE}")"
HAS_PG_LOCAL="$(jq -r '.infra_probe.has_pg_local' "${INFRA_FILE}")"

STATUS="RED"
if [ "${WEB_OK}" = "true" ] && [ "${RPC_OK}" = "true" ] && [ "${ODOO_ACTIVE}" = "true" ] && [ "${NGINX_ACTIVE}" = "true" ] && [ "${PG_ACTIVE}" = "true" ] && [ "${HAS_NGINX_8069}" = "true" ] && [ "${HAS_ODOO_8070}" = "true" ] && [ "${HAS_PG_LOCAL}" = "true" ]; then
  STATUS="GREEN"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg web_file "${WEB_FILE}" \
  --arg rpc_file "${RPC_FILE}" \
  --arg infra_file "${INFRA_FILE}" \
  --arg status "${STATUS}" \
  --argjson web_ok "${WEB_OK}" \
  --argjson rpc_ok "${RPC_OK}" \
  --argjson odoo_active "${ODOO_ACTIVE}" \
  --argjson nginx_active "${NGINX_ACTIVE}" \
  --argjson pg_active "${PG_ACTIVE}" \
  --argjson has_nginx_8069 "${HAS_NGINX_8069}" \
  --argjson has_odoo_8070 "${HAS_ODOO_8070}" \
  --argjson has_pg_local "${HAS_PG_LOCAL}" \
  '{
    created_at: $created_at,
    monitoring_status: {
      web_file: $web_file,
      rpc_file: $rpc_file,
      infra_file: $infra_file,
      web_ok: $web_ok,
      rpc_ok: $rpc_ok,
      odoo_active: $odoo_active,
      nginx_active: $nginx_active,
      pg_active: $pg_active,
      has_nginx_8069: $has_nginx_8069,
      has_odoo_8070: $has_odoo_8070,
      has_pg_local: $has_pg_local,
      status: $status
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 90 — ODOO Monitoring Status

## Status
- web_ok: ${WEB_OK}
- rpc_ok: ${RPC_OK}
- odoo_active: ${ODOO_ACTIVE}
- nginx_active: ${NGINX_ACTIVE}
- pg_active: ${PG_ACTIVE}
- has_nginx_8069: ${HAS_NGINX_8069}
- has_odoo_8070: ${HAS_ODOO_8070}
- has_pg_local: ${HAS_PG_LOCAL}
- status: ${STATUS}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] monitoring status gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
