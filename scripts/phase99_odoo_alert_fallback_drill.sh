#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase99_alert_fallback_drill_${TS}.txt"
OUT_JSON="logs/executive/phase99_odoo_alert_fallback_drill_${TS}.json"
OUT_MD="docs/generated/phase99_odoo_alert_fallback_drill_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" \
  ssh -T -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
  "ODOO_SSH_USER='${ODOO_SSH_USER}' bash -s" > "${RAW_FILE}" 2>&1 <<'REMOTE'

set -euo pipefail

BASE_DIR="/home/${ODOO_SSH_USER}/odoo_watchdog"
ENV_FILE="${BASE_DIR}/alert.env"
LOG_DIR="${BASE_DIR}/logs"
FAILED_DIR="${LOG_DIR}/failed_queue"
ENV_BAK="${BASE_DIR}/alert.env.phase99.drill.bak"

cp "${ENV_FILE}" "${ENV_BAK}"

python3 - <<'PY'
from pathlib import Path
import os

user = os.environ["ODOO_SSH_USER"]
p = Path(f"/home/{user}/odoo_watchdog/alert.env")
txt = p.read_text()
if "hooks.slack.com" not in txt:
    raise SystemExit("webhook slack nao encontrado no alert.env")
txt = txt.replace("hooks.slack.com", "invalid.local", 1)
p.write_text(txt)
print("[OK] webhook temporariamente invalidado")
PY

set +e
"${BASE_DIR}/send_alert.sh"
EC=$?
set -e

mv "${ENV_BAK}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

echo '===== EXIT CODE ====='
echo "${EC}"
echo
echo '===== LAST ALERT ====='
LAST_ALERT=$(ls -1t "${LOG_DIR}"/alert_delivery_*.json 2>/dev/null | head -n 1 || true)
echo "${LAST_ALERT}"
[ -n "${LAST_ALERT}" ] && cat "${LAST_ALERT}"
echo
echo '===== LAST FALLBACK ====='
LAST_FAIL=$(ls -1t "${FAILED_DIR}"/alert_failed_*.json 2>/dev/null | head -n 1 || true)
echo "${LAST_FAIL}"
[ -n "${LAST_FAIL}" ] && cat "${LAST_FAIL}"
REMOTE
SSH_RC=$?

ALERT_FAILED=false
FALLBACK_WRITTEN=false

grep -q '"http_ok": false' "${RAW_FILE}" && ALERT_FAILED=true || true
grep -q 'alert_failed_' "${RAW_FILE}" && FALLBACK_WRITTEN=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson alert_failed "${ALERT_FAILED}" \
  --argjson fallback_written "${FALLBACK_WRITTEN}" \
  '{
    created_at: $created_at,
    fallback_drill: {
      raw_file: $raw_file,
      alert_failed: $alert_failed,
      fallback_written: $fallback_written,
      overall_ok: ($alert_failed and $fallback_written)
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 99 — ODOO Alert Fallback Drill

## Drill
- raw_file: ${RAW_FILE}
- alert_failed: ${ALERT_FAILED}
- fallback_written: ${FALLBACK_WRITTEN}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] fallback drill gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
