#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase87_odoo_smoke_evidence_${TS}.json"
OUT_MD="docs/generated/phase87_odoo_smoke_evidence_${TS}.md"

SEED_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_seed_*.json 2>/dev/null | head -n 1 || true)"
WEB_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_web_probe_*.json 2>/dev/null | head -n 1 || true)"
RPC_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_rpc_probe_*.json 2>/dev/null | head -n 1 || true)"
INFRA_FILE="$(ls -1t logs/executive/phase87_odoo_smoke_infra_probe_*.json 2>/dev/null | head -n 1 || true)"
ROLLBACK_FILE="$(ls -1t logs/executive/phase87_odoo_rollback_readiness_*.json 2>/dev/null | head -n 1 || true)"

WEB_OK="$(jq -r '.web_probe.http_ok and .web_probe.login_page_ok' "${WEB_FILE}")"
RPC_OK="$(jq -r '.rpc_probe.xmlrpc_common_ok and .rpc_probe.auth_ok' "${RPC_FILE}")"
INFRA_OK="$(jq -r '.infra_probe.has_nginx_8069 and .infra_probe.has_odoo_8070 and .infra_probe.has_pg_local and .infra_probe.public_has_nginx' "${INFRA_FILE}")"
ROLLBACK_READY="$(jq -r '.rollback_readiness.rollback_ready' "${ROLLBACK_FILE}")"

FLOW_OK=false
if [ "${WEB_OK}" = "true" ] && [ "${RPC_OK}" = "true" ] && [ "${INFRA_OK}" = "true" ] && [ "${ROLLBACK_READY}" = "true" ]; then
  FLOW_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg seed_file "${SEED_FILE}" \
  --arg web_file "${WEB_FILE}" \
  --arg rpc_file "${RPC_FILE}" \
  --arg infra_file "${INFRA_FILE}" \
  --arg rollback_file "${ROLLBACK_FILE}" \
  --argjson web_ok "${WEB_OK}" \
  --argjson rpc_ok "${RPC_OK}" \
  --argjson infra_ok "${INFRA_OK}" \
  --argjson rollback_ready "${ROLLBACK_READY}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    smoke_flow: {
      seed_file: $seed_file,
      web_file: $web_file,
      rpc_file: $rpc_file,
      infra_file: $infra_file,
      rollback_file: $rollback_file,
      web_ok: $web_ok,
      rpc_ok: $rpc_ok,
      infra_ok: $infra_ok,
      rollback_ready: $rollback_ready,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 87 — ODOO Smoke Evidence

## Flow
- web_ok: ${WEB_OK}
- rpc_ok: ${RPC_OK}
- infra_ok: ${INFRA_OK}
- rollback_ready: ${ROLLBACK_READY}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] smoke evidence gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
