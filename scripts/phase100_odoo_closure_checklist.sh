#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase100_odoo_closure_checklist_${TS}.json"
OUT_MD="docs/generated/phase100_odoo_closure_checklist_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    checklist: {
      items: [
        "confirmar cron do watchdog remoto",
        "confirmar cron de retention/housekeeping",
        "verificar last_run.json com overall_ok true",
        "verificar ultimo alert_delivery com http_ok true",
        "verificar fila failed_queue visivel",
        "executar probe funcional quando houver alteracao relevante",
        "preservar webhook slack atualizado em alert.env",
        "usar baseline git/tag antes de qualquer mudanca estrutural"
      ],
      handoff_ready: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 100 — ODOO Closure Checklist

## Checklist Operacional
- confirmar cron do watchdog remoto
- confirmar cron de retention/housekeeping
- verificar last_run.json com overall_ok true
- verificar ultimo alert_delivery com http_ok true
- verificar fila failed_queue visivel
- executar probe funcional quando houver alteracao relevante
- preservar webhook slack atualizado em alert.env
- usar baseline git/tag antes de qualquer mudanca estrutural

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] closure checklist gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
