#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase84_odoo_surface_evidence_${TS}.json"
OUT_MD="docs/generated/phase84_odoo_surface_evidence_${TS}.md"

APPLY_FILE="$(ls -1t logs/executive/phase84_odoo_surface_reduce_apply_*.json 2>/dev/null | head -n 1 || true)"
POST_FILE="$(ls -1t logs/executive/phase84_odoo_post_surface_probe_*.json 2>/dev/null | head -n 1 || true)"
PACKET83="$(ls -1t logs/executive/phase83_odoo_hardening_packet_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${APPLY_FILE}" ] || [ -z "${POST_FILE}" ] || [ -z "${PACKET83}" ]; then
  echo "[ERRO] apply/post/packet83 files nao encontrados"
  exit 1
fi

LIST_DB_SET="$(jq -r '.apply.list_db_set // false' "${APPLY_FILE}")"
HTTP_OK="$(jq -r '.post_surface_probe.http_ok // false' "${POST_FILE}")"
AUTH_OK="$(jq -r '.post_surface_probe.auth_ok // false' "${POST_FILE}")"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 4.5' "${PACKET83}")"

FLOW_OK=false
if [ "${LIST_DB_SET}" = "true" ] && [ "${HTTP_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg apply_file "${APPLY_FILE}" \
  --arg post_file "${POST_FILE}" \
  --argjson list_db_set "${LIST_DB_SET}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  '{
    created_at: $created_at,
    surface_flow: {
      apply_file: $apply_file,
      post_file: $post_file,
      list_db_set: $list_db_set,
      http_ok: $http_ok,
      auth_ok: $auth_ok,
      flow_ok: $flow_ok
    },
    score_reference: {
      odoo_score_before: ($score_before | tonumber)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 84 — ODOO Surface Evidence

## Flow
- list_db_set: ${LIST_DB_SET}
- http_ok: ${HTTP_OK}
- auth_ok: ${AUTH_OK}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] surface evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
