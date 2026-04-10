#!/usr/bin/env bash
set -euo pipefail

cd /Users/jarvis001/jarvis

mkdir -p runtime/odoo/watchdog logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="runtime/odoo/watchdog/watchdog_runner_${TS}.log"
OUT_JSON="logs/executive/phase92_odoo_watchdog_runner_${TS}.json"
OUT_MD="docs/generated/phase92_odoo_watchdog_runner_${TS}.md"

{
  echo "===== PHASE 92 ODOO WATCHDOG RUNNER ====="
  echo "TS=${TS}"

  ./scripts/phase91_odoo_watchdog_seed.sh
  python3 scripts/phase91_odoo_watchdog_run.py
  ./scripts/phase91_odoo_watchdog_infra.sh
  ./scripts/phase91_odoo_alert_artifact.sh
  ./scripts/phase91_odoo_watchdog_evidence.sh
  ./scripts/phase91_odoo_watchdog_packet.sh

  WATCHDOG_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_run_*.json 2>/dev/null | head -n 1 || true)"
  INFRA_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_infra_*.json 2>/dev/null | head -n 1 || true)"
  ALERT_FILE="$(ls -1t logs/executive/phase91_odoo_alert_artifact_*.json 2>/dev/null | head -n 1 || true)"
  EVIDENCE_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
  PACKET_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_packet_*.json 2>/dev/null | head -n 1 || true)"

  echo
  echo "WATCHDOG_FILE=${WATCHDOG_FILE}"
  echo "INFRA_FILE=${INFRA_FILE}"
  echo "ALERT_FILE=${ALERT_FILE}"
  echo "EVIDENCE_FILE=${EVIDENCE_FILE}"
  echo "PACKET_FILE=${PACKET_FILE}"
} | tee "${RUN_LOG}"

WATCHDOG_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_run_*.json 2>/dev/null | head -n 1 || true)"
INFRA_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_infra_*.json 2>/dev/null | head -n 1 || true)"
ALERT_FILE="$(ls -1t logs/executive/phase91_odoo_alert_artifact_*.json 2>/dev/null | head -n 1 || true)"
EVIDENCE_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_evidence_*.json 2>/dev/null | head -n 1 || true)"
PACKET_FILE="$(ls -1t logs/executive/phase91_odoo_watchdog_packet_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.watchdog_flow.flow_ok' "${EVIDENCE_FILE}")"
ALERT_STATUS="$(jq -r '.alert_artifact.status' "${ALERT_FILE}")"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg run_log "${RUN_LOG}" \
  --arg watchdog_file "${WATCHDOG_FILE}" \
  --arg infra_file "${INFRA_FILE}" \
  --arg alert_file "${ALERT_FILE}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --arg packet_file "${PACKET_FILE}" \
  --arg alert_status "${ALERT_STATUS}" \
  --argjson flow_ok "${FLOW_OK}" \
  '{
    created_at: $created_at,
    runner: {
      run_log: $run_log,
      watchdog_file: $watchdog_file,
      infra_file: $infra_file,
      alert_file: $alert_file,
      evidence_file: $evidence_file,
      packet_file: $packet_file,
      alert_status: $alert_status,
      flow_ok: $flow_ok
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 92 — ODOO Watchdog Runner

## Runner
- run_log: ${RUN_LOG}
- watchdog_file: ${WATCHDOG_FILE}
- infra_file: ${INFRA_FILE}
- alert_file: ${ALERT_FILE}
- evidence_file: ${EVIDENCE_FILE}
- packet_file: ${PACKET_FILE}
- alert_status: ${ALERT_STATUS}
- flow_ok: ${FLOW_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] watchdog runner gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
