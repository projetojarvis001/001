#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase102_odoo_secrets_hardening_packet_${TS}.json"
OUT_MD="docs/generated/phase102_odoo_secrets_hardening_packet_${TS}.md"

PROBE_FILE="$(ls -1t logs/executive/phase102_odoo_secrets_hardening_probe_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.secrets_hardening_probe.overall_ok // false' "${PROBE_FILE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg probe_file "${PROBE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_102_ODOO_SECRETS_HARDENING",
      flow_ok: $flow_ok
    },
    decision: {
      operator_note: "Operacao do watchdog do odoo migrada para carregamento seguro de segredos locais ignorados pelo git."
    },
    sources: {
      probe_file: $probe_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 102 — ODOO Secrets Hardening Packet

## Summary
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase102 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
