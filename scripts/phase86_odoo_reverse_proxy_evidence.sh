#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase86_odoo_reverse_proxy_evidence_${TS}.json"
OUT_MD="docs/generated/phase86_odoo_reverse_proxy_evidence_${TS}.md"

APPLY_FILE="$(ls -1t logs/executive/phase86_odoo_reverse_proxy_apply_*.json 2>/dev/null | head -n 1 || true)"
POST_FILE="$(ls -1t logs/executive/phase86_odoo_post_proxy_probe_*.json 2>/dev/null | head -n 1 || true)"
PACKET85="$(ls -1t logs/executive/phase85_odoo_exposure_packet_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${APPLY_FILE}" ] || [ -z "${POST_FILE}" ] || [ -z "${PACKET85}" ]; then
  echo "[ERRO] arquivos da fase 86 nao encontrados"
  exit 1
fi

PROXY_MODE_SET="$(jq -r '.apply.proxy_mode_set // false' "${APPLY_FILE}")"
LIST_DB_SET="$(jq -r '.apply.list_db_set // false' "${APPLY_FILE}")"
DBFILTER_SET="$(jq -r '.apply.dbfilter_set // false' "${APPLY_FILE}")"
HTTP_INTERFACE_LOCAL="$(jq -r '.apply.http_interface_local // false' "${APPLY_FILE}")"
NGINX_TEST_OK="$(jq -r '.apply.nginx_test_ok // false' "${APPLY_FILE}")"

HTTP_OK="$(jq -r '.post_proxy_probe.http_ok // false' "${POST_FILE}")"
AUTH_OK="$(jq -r '.post_proxy_probe.auth_ok // false' "${POST_FILE}")"
SERVER_HEADER="$(jq -r '.post_proxy_probe.server_header // ""' "${POST_FILE}")"

FLOW_OK=false
if [ "${PROXY_MODE_SET}" = "true" ] && \
   [ "${LIST_DB_SET}" = "true" ] && \
   [ "${DBFILTER_SET}" = "true" ] && \
   [ "${HTTP_INTERFACE_LOCAL}" = "true" ] && \
   [ "${NGINX_TEST_OK}" = "true" ] && \
   [ "${HTTP_OK}" = "true" ] && \
   [ "${AUTH_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg apply_file "${APPLY_FILE}" \
  --arg post_file "${POST_FILE}" \
  --arg server_header "${SERVER_HEADER}" \
  --argjson proxy_mode_set "${PROXY_MODE_SET}" \
  --argjson list_db_set "${LIST_DB_SET}" \
  --argjson dbfilter_set "${DBFILTER_SET}" \
  --argjson http_interface_local "${HTTP_INTERFACE_LOCAL}" \
  --argjson nginx_test_ok "${NGINX_TEST_OK}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    reverse_proxy_flow: {
      apply_file: $apply_file,
      post_file: $post_file,
      server_header: $server_header,
      proxy_mode_set: $proxy_mode_set,
      list_db_set: $list_db_set,
      dbfilter_set: $dbfilter_set,
      http_interface_local: $http_interface_local,
      nginx_test_ok: $nginx_test_ok,
      http_ok: $http_ok,
      auth_ok: $auth_ok,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 86 — ODOO Reverse Proxy Evidence

## Flow
- server_header: ${SERVER_HEADER}
- proxy_mode_set: ${PROXY_MODE_SET}
- list_db_set: ${LIST_DB_SET}
- dbfilter_set: ${DBFILTER_SET}
- http_interface_local: ${HTTP_INTERFACE_LOCAL}
- nginx_test_ok: ${NGINX_TEST_OK}
- http_ok: ${HTTP_OK}
- auth_ok: ${AUTH_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] reverse proxy evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
