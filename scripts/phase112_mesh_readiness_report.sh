#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase112_mesh_readiness_report_${TS}.json"
OUT_MD="docs/generated/phase112_mesh_readiness_report_${TS}.md"
OUT_REPORT="reports/phase112_mesh_readiness_report.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

STATE_FILE="readiness/mesh_readiness_state.json"

READY_COUNT="$(jq -r '.mesh_readiness.ready_count' "${STATE_FILE}")"
BLOCKED_COUNT="$(jq -r '.mesh_readiness.blocked_count' "${STATE_FILE}")"
STATUS="$(jq -r '.mesh_readiness.status' "${STATE_FILE}")"

cat > "${OUT_REPORT}" <<MD
# Phase 112 Mesh Readiness Report

- status: ${STATUS}
- ready_count: ${READY_COUNT}
- blocked_count: ${BLOCKED_COUNT}

## Nodes
$(jq -r '.mesh_readiness.nodes[] | "- \(.name): \(.status)"' "${STATE_FILE}")

## Veredito
A malha está estruturada, mas só pode avançar para bootstrap real quando os nós bloqueados receberem host, usuário e credencial válidos.
MD

jq -n \
  --arg created_at "${created_at}" \
  --arg report_file "${OUT_REPORT}" \
  '{
    created_at: $created_at,
    readiness_report: {
      report_file: $report_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 112 — Mesh Readiness Report

## Report
- report_file: ${OUT_REPORT}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase112 report gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
echo
sed -n '1,220p' "${OUT_REPORT}"
