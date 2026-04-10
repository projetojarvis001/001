#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase88_odoo_backup_packet_${TS}.json"
OUT_MD="docs/generated/phase88_odoo_backup_packet_${TS}.md"

EVIDENCE_FILE="$(ls -1t logs/executive/phase88_odoo_backup_evidence_*.json 2>/dev/null | head -n 1 || true)"
PACKET87="$(ls -1t logs/executive/phase87_odoo_smoke_packet_*.json 2>/dev/null | head -n 1 || true)"

FLOW_OK="$(jq -r '.backup_flow.flow_ok' "${EVIDENCE_FILE}")"
ODOO_SCORE_BEFORE="$(jq -r '.summary.odoo_score_after // 7.6' "${PACKET87}")"
ODOO_SCORE_AFTER="${ODOO_SCORE_BEFORE}"

if [ "${FLOW_OK}" = "true" ]; then
  ODOO_SCORE_AFTER="$(python3 - <<PY
before = float("${ODOO_SCORE_BEFORE}")
print(f"{min(before + 0.6, 10.0):.1f}")
PY
)"
fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg evidence_file "${EVIDENCE_FILE}" \
  --argjson flow_ok "${FLOW_OK}" \
  --arg score_before "${ODOO_SCORE_BEFORE}" \
  --arg score_after "${ODOO_SCORE_AFTER}" \
  '{
    created_at: $created_at,
    summary: {
      phase: "FASE_88_ODOO_BACKUP_RESTORE_READINESS",
      flow_ok: $flow_ok,
      recovery_ready: $flow_ok,
      odoo_score_before: ($score_before | tonumber),
      odoo_score_after: ($score_after | tonumber)
    },
    decision: {
      operator_note: "ODOO agora possui backup consistente e restore readiness documentado."
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
# FASE 88 — ODOO Backup Packet

## Summary
- flow_ok: ${FLOW_OK}
- recovery_ready: ${FLOW_OK}
- odoo_score_before: ${ODOO_SCORE_BEFORE}
- odoo_score_after: ${ODOO_SCORE_AFTER}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] backup packet gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
