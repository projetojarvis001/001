#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase100_odoo_closure_consolidation_${TS}.json"
OUT_MD="docs/generated/phase100_odoo_closure_consolidation_${TS}.md"

PHASE91="$(ls -1t logs/executive/phase91_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE93="$(ls -1t logs/executive/phase93_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE94="$(ls -1t logs/executive/phase94_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE95="$(ls -1t logs/executive/phase95_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE97="$(ls -1t logs/executive/phase97_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE98="$(ls -1t logs/executive/phase98_*packet*.json 2>/dev/null | head -n 1 || true)"
PHASE99="$(ls -1t logs/executive/phase99_*packet*.json 2>/dev/null | head -n 1 || true)"

P91_OK=false
P93_OK=false
P94_OK=false
P95_OK=false
P97_OK=false
P98_OK=false
P99_OK=false

[ -n "${PHASE91}" ] && jq -e '.summary.flow_ok == true' "${PHASE91}" >/dev/null && P91_OK=true || true
[ -n "${PHASE93}" ] && jq -e '.summary.flow_ok == true' "${PHASE93}" >/dev/null && P93_OK=true || true
[ -n "${PHASE94}" ] && jq -e '.summary.flow_ok == true' "${PHASE94}" >/dev/null && P94_OK=true || true
[ -n "${PHASE95}" ] && jq -e '.summary.flow_ok == true' "${PHASE95}" >/dev/null && P95_OK=true || true
[ -n "${PHASE97}" ] && jq -e '.summary.flow_ok == true' "${PHASE97}" >/dev/null && P97_OK=true || true
[ -n "${PHASE98}" ] && jq -e '.summary.flow_ok == true' "${PHASE98}" >/dev/null && P98_OK=true || true
[ -n "${PHASE99}" ] && jq -e '.summary.flow_ok == true' "${PHASE99}" >/dev/null && P99_OK=true || true

PROGRAM_OK=false
if [ "${P91_OK}" = "true" ] && [ "${P93_OK}" = "true" ] && [ "${P94_OK}" = "true" ] && \
   [ "${P95_OK}" = "true" ] && [ "${P97_OK}" = "true" ] && [ "${P98_OK}" = "true" ] && \
   [ "${P99_OK}" = "true" ]; then
  PROGRAM_OK=true
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg phase91 "${PHASE91}" \
  --arg phase93 "${PHASE93}" \
  --arg phase94 "${PHASE94}" \
  --arg phase95 "${PHASE95}" \
  --arg phase97 "${PHASE97}" \
  --arg phase98 "${PHASE98}" \
  --arg phase99 "${PHASE99}" \
  --argjson p91_ok "${P91_OK}" \
  --argjson p93_ok "${P93_OK}" \
  --argjson p94_ok "${P94_OK}" \
  --argjson p95_ok "${P95_OK}" \
  --argjson p97_ok "${P97_OK}" \
  --argjson p98_ok "${P98_OK}" \
  --argjson p99_ok "${P99_OK}" \
  --argjson program_ok "${PROGRAM_OK}" \
  '{
    created_at: $created_at,
    consolidation: {
      phase91_packet: $phase91,
      phase93_packet: $phase93,
      phase94_packet: $phase94,
      phase95_packet: $phase95,
      phase97_packet: $phase97,
      phase98_packet: $phase98,
      phase99_packet: $phase99,
      phase91_ok: $p91_ok,
      phase93_ok: $p93_ok,
      phase94_ok: $p94_ok,
      phase95_ok: $p95_ok,
      phase97_ok: $p97_ok,
      phase98_ok: $p98_ok,
      phase99_ok: $p99_ok,
      program_ok: $program_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 100 — ODOO Closure Consolidation

## Program
- phase91_ok: ${P91_OK}
- phase93_ok: ${P93_OK}
- phase94_ok: ${P94_OK}
- phase95_ok: ${P95_OK}
- phase97_ok: ${P97_OK}
- phase98_ok: ${P98_OK}
- phase99_ok: ${P99_OK}
- program_ok: ${PROGRAM_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] closure consolidation gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
