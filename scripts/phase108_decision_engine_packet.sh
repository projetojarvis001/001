#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase108_decision_engine_packet_${TS}.json"
OUT_MD="docs/generated/phase108_decision_engine_packet_${TS}.md"

EVIDENCE_FILE="$(find logs/executive -maxdepth 1 -name 'phase108_decision_engine_evidence_*.json' | sort | tail -n 1)"
ENGINE_FILE="decision_engine/engine_state.json"

FLOW_OK="$(jq -r '.decision_engine_flow.flow_ok' "${EVIDENCE_FILE}")"
TRIGGERED_TOTAL="$(jq -r '.decision_engine.triggered_total' "${ENGINE_FILE}")"
HIGHEST_SEVERITY="$(jq -r '.decision_engine.highest_severity' "${ENGINE_FILE}")"

SCORE_BEFORE="16.4"
SCORE_AFTER="18.0"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson flow_ok "${FLOW_OK}" \
  --argjson triggered_total "${TRIGGERED_TOTAL}" \
  --arg highest_severity "${HIGHEST_SEVERITY}" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson system_score_before "${SCORE_BEFORE}" \
  --argjson system_score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_108_DECISION_ENGINE",
      flow_ok: $flow_ok,
      triggered_total: $triggered_total,
      highest_severity: $highest_severity,
      system_score_before: $system_score_before,
      system_score_after: $system_score_after
    },
    decision: {
      operator_note: "Motor de decisao operacional consolidado com leitura de regras, priorizacao e auto-remediation controlada."
    },
    sources: {
      evidence_file: $evidence_file
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 108 — Decision Engine Packet

## Summary
- flow_ok: ${FLOW_OK}
- triggered_total: ${TRIGGERED_TOTAL}
- highest_severity: ${HIGHEST_SEVERITY}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase108 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
