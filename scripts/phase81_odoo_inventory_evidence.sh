#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase81_odoo_inventory_evidence_${TS}.json"
OUT_MD="docs/generated/phase81_odoo_inventory_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase81_odoo_inventory_seed_*.json 2>/dev/null | head -n 1 || true)"
REMOTE_FILE="$(ls -1t logs/executive/phase81_odoo_remote_probe_*.json 2>/dev/null | head -n 1 || true)"
APP_FILE="$(ls -1t logs/executive/phase81_odoo_app_probe_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${SEED_FILE}" ] || [ -z "${REMOTE_FILE}" ] || [ -z "${APP_FILE}" ]; then
  echo "[ERRO] seed/probe files nao encontrados"
  exit 1
fi

HOSTNAME="$(jq -r '.remote_probe.hostname // ""' "${REMOTE_FILE}")"
ODOO_PROC_COUNT="$(jq -r '.remote_probe.odoo_proc_count // 0' "${REMOTE_FILE}")"
PG_PROC_COUNT="$(jq -r '.remote_probe.postgres_proc_count // 0' "${REMOTE_FILE}")"
HAS_8069="$(jq -r '.remote_probe.has_8069 // false' "${REMOTE_FILE}")"
AUTH_OK="$(jq -r '.app_probe.auth_ok // false' "${APP_FILE}")"
HTTP_OK="$(jq -r '.app_probe.http_ok // false' "${APP_FILE}")"
SERVER_VERSION="$(jq -r '.app_probe.server_version // ""' "${APP_FILE}")"

READINESS_OK=false
if [ "${HTTP_OK}" = "true" ] && [ "${AUTH_OK}" = "true" ]; then
  READINESS_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg remote_file "${REMOTE_FILE}" \
  --arg app_file "${APP_FILE}" \
  --arg hostname "${HOSTNAME}" \
  --argjson odoo_proc_count "${ODOO_PROC_COUNT}" \
  --argjson postgres_proc_count "${PG_PROC_COUNT}" \
  --argjson has_8069 "${HAS_8069}" \
  --argjson http_ok "${HTTP_OK}" \
  --argjson auth_ok "${AUTH_OK}" \
  --arg server_version "${SERVER_VERSION}" \
  --argjson readiness_ok "${READINESS_OK}" \
  '{
    created_at: $created_at,
    inventory_flow: {
      seed_file: $seed_file,
      remote_file: $remote_file,
      app_file: $app_file,
      hostname: $hostname,
      odoo_proc_count: $odoo_proc_count,
      postgres_proc_count: $postgres_proc_count,
      has_8069: $has_8069,
      http_ok: $http_ok,
      auth_ok: $auth_ok,
      server_version: $server_version,
      readiness_ok: $readiness_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 81 — ODOO Inventory Evidence

## Flow
- hostname: ${HOSTNAME}
- odoo_proc_count: ${ODOO_PROC_COUNT}
- postgres_proc_count: ${PG_PROC_COUNT}
- has_8069: ${HAS_8069}
- http_ok: ${HTTP_OK}
- auth_ok: ${AUTH_OK}
- server_version: ${SERVER_VERSION}
- readiness_ok: ${READINESS_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] odoo inventory evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
