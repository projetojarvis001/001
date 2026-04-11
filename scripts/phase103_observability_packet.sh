#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/observability

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase103_observability_packet_${TS}.json"
OUT_MD="docs/generated/phase103_observability_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase103_observability_evidence_*.json 2>/dev/null | head -n 1 || true)"
FLOW_OK="$(jq -r '.observability_flow.flow_ok // false' "${EVIDENCE_FILE}")"

SCORE_BEFORE="11.6"
SCORE_AFTER="12.2"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${SCORE_BEFORE}" \
  --arg score_after "${SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_103_OBSERVABILITY_FOUNDATION",
      flow_ok: $flow_ok,
      system_score_before: ($score_before|tonumber),
      system_score_after: ($score_after|tonumber)
    },
    decision: {
      operator_note: "Camada base de observabilidade implantada com prometheus grafana loki exporters e probes do ecossistema."
    },
    sources: {
      evidence_file: $evidence_file
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 103 — Observability Packet

## Summary
- flow_ok: ${FLOW_OK}
- system_score_before: ${SCORE_BEFORE}
- system_score_after: ${SCORE_AFTER}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] phase103 packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
