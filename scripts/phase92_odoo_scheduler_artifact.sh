#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo/watchdog

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase92_odoo_scheduler_artifact_${TS}.json"
OUT_MD="docs/generated/phase92_odoo_scheduler_artifact_${TS}.md"
CRON_FILE="runtime/odoo/watchdog/odoo_watchdog.cron"

RUNNER_PATH="/Users/jarvis001/jarvis/scripts/phase92_odoo_watchdog_runner.sh"
CRON_EXPR="*/5 * * * *"
CRON_LINE="${CRON_EXPR} ${RUNNER_PATH} >> /Users/jarvis001/jarvis/runtime/odoo/watchdog/cron_stdout.log 2>&1"

cat > "${CRON_FILE}" <<CRON
${CRON_LINE}
CRON

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg cron_file "${CRON_FILE}" \
  --arg cron_expr "${CRON_EXPR}" \
  --arg cron_line "${CRON_LINE}" \
  '{
    created_at: $created_at,
    scheduler_artifact: {
      cron_file: $cron_file,
      cron_expr: $cron_expr,
      cron_line: $cron_line,
      scheduler_ready: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 92 — ODOO Scheduler Artifact

## Artifact
- cron_file: ${CRON_FILE}
- cron_expr: ${CRON_EXPR}
- scheduler_ready: true

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] scheduler artifact gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
