#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase87_odoo_rollback_readiness_${TS}.json"
OUT_MD="docs/generated/phase87_odoo_rollback_readiness_${TS}.md"

LAST_BACKUP="$(sshpass -p "${ODOO_SSH_PASS}" ssh -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
"echo '${ODOO_SSH_PASS}' | sudo -S find /etc -maxdepth 1 -type f -name 'odoo.conf.bak.phase*' 2>/dev/null | sort | tail -n 1" | tr -d '\r' | xargs || true)"

ROLLBACK_READY=false
[ -n "${LAST_BACKUP}" ] && ROLLBACK_READY=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg last_backup "${LAST_BACKUP}" \
  --arg rollback_cmd "sudo cp ${LAST_BACKUP} /etc/odoo.conf && sudo systemctl restart odoo" \
  --argjson rollback_ready "${ROLLBACK_READY}" \
  '{
    created_at: $created_at,
    rollback_readiness: {
      last_backup: $last_backup,
      rollback_cmd: $rollback_cmd,
      rollback_ready: $rollback_ready
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 87 — ODOO Rollback Readiness

## Rollback
- last_backup: ${LAST_BACKUP}
- rollback_ready: ${ROLLBACK_READY}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] rollback readiness gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
