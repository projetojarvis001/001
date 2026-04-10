#!/usr/bin/env bash
set -e
mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase86_final_odoo_proxy_evidence_${TS}.json"
OUT_MD="docs/generated/phase86_final_odoo_proxy_evidence_${TS}.md"

POST_FILE="$(ls -1t logs/executive/phase86_odoo_post_proxy_probe_*.json 2>/dev/null | head -n 1 || true)"
PACKET85="$(ls -1t logs/executive/phase85_odoo_exposure_packet_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${POST_FILE}" ]; then
  echo "[ERRO] post probe nao encontrado"
  exit 1
fi

SERVER_HEADER="$(jq -r '.post_proxy_probe.server_header // ""' "${POST_FILE}")"
HTTP_OK="$(jq -r '.post_proxy_probe.http_ok // false' "${POST_FILE}")"
AUTH_OK="$(jq -r '.post_proxy_probe.auth_ok // false' "${POST_FILE}")"

HEADER_IS_NGINX=false
echo "${SERVER_HEADER}" | grep -qi 'nginx' && HEADER_IS_NGINX=true || true

FLOW_OK=false
if [ "${HTTP_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ] && [ "${HEADER_IS_NGINX}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg post_file "${POST_FILE}" \
  --arg server_header "${SERVER_HEADER}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson header_is_nginx "${HEADER_IS_NGINX}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    proxy_final_flow: {
      post_file: $post_file,
      server_header: $server_header,
      http_ok: $http_ok,
      auth_ok: $auth_ok,
      header_is_nginx: $header_is_nginx,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 86 FINAL — ODOO PROXY EVIDENCE

## Flow
- server_header: ${SERVER_HEADER}
- http_ok: ${HTTP_OK}
- auth_ok: ${AUTH_OK}
- header_is_nginx: ${HEADER_IS_NGINX}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase86 final evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
