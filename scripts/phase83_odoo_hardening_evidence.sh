#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase83_odoo_hardening_evidence_${TS}.json"
OUT_MD="docs/generated/phase83_odoo_hardening_evidence_${TS}.md"

APPLY_FILE="$(ls -1t logs/executive/phase83_odoo_hardening_apply_*.json 2>/dev/null | head -n 1 || true)"
POST_FILE="$(ls -1t logs/executive/phase83_odoo_post_apply_probe_*.json 2>/dev/null | head -n 1 || true)"
RISK82="$(ls -1t logs/executive/phase82_odoo_risk_assessment_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${APPLY_FILE}" ] || [ -z "${POST_FILE}" ] || [ -z "${RISK82}" ]; then
  echo "[ERRO] apply/post/risk files nao encontrados"
  exit 1
fi

RAW_FILE="$(jq -r '.apply.raw_file // ""' "${APPLY_FILE}")"
PROXY_MODE_SET_JSON="$(jq -r '.apply.proxy_mode_set // false' "${APPLY_FILE}")"
DBFILTER_SET_JSON="$(jq -r '.apply.dbfilter_set // false' "${APPLY_FILE}")"

PROXY_MODE_SET_RAW=false
DBFILTER_SET_RAW=false

tr -d '\r' < "${RAW_FILE}" | grep -q '^proxy_mode = True$' && PROXY_MODE_SET_RAW=true || true
tr -d '\r' < "${RAW_FILE}" | grep -q '^dbfilter = ^WPS$' && DBFILTER_SET_RAW=true || true

HTTP_OK="$(jq -r '.post_apply_probe.http_ok // false' "${POST_FILE}")"
AUTH_OK="$(jq -r '.post_apply_probe.auth_ok // false' "${POST_FILE}")"
RISK_BEFORE="$(jq -r '.risk.risk_level // ""' "${RISK82}")"

FLOW_OK=false
if { [ "${PROXY_MODE_SET_JSON}" = "true" ] || [ "${PROXY_MODE_SET_RAW}" = "true" ]; } && \
   { [ "${DBFILTER_SET_JSON}" = "true" ] || [ "${DBFILTER_SET_RAW}" = "true" ]; } && \
   [ "${HTTP_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg apply_file "${APPLY_FILE}" \
  --arg post_file "${POST_FILE}" \
  --arg raw_file "${RAW_FILE}" \
  --arg risk_before "${RISK_BEFORE}" \
  --argjson proxy_mode_set_json "${PROXY_MODE_SET_JSON}" \
  --argjson dbfilter_set_json "${DBFILTER_SET_JSON}" \
  --argjson proxy_mode_set_raw "${PROXY_MODE_SET_RAW}" \
  --argjson dbfilter_set_raw "${DBFILTER_SET_RAW}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    hardening_flow: {
      apply_file: $apply_file,
      post_file: $post_file,
      raw_file: $raw_file,
      risk_before: $risk_before,
      proxy_mode_set_json: $proxy_mode_set_json,
      dbfilter_set_json: $dbfilter_set_json,
      proxy_mode_set_raw: $proxy_mode_set_raw,
      dbfilter_set_raw: $dbfilter_set_raw,
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
# FASE 83 — ODOO Hardening Evidence

## Flow
- risk_before: ${RISK_BEFORE}
- proxy_mode_set_json: ${PROXY_MODE_SET_JSON}
- dbfilter_set_json: ${DBFILTER_SET_JSON}
- proxy_mode_set_raw: ${PROXY_MODE_SET_RAW}
- dbfilter_set_raw: ${DBFILTER_SET_RAW}
- http_ok: ${HTTP_OK}
- auth_ok: ${AUTH_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] hardening evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
