#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase99_alert_fallback_apply_${TS}.txt"
OUT_JSON="logs/executive/phase99_odoo_alert_fallback_apply_${TS}.json"
OUT_MD="docs/generated/phase99_odoo_alert_fallback_apply_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" \
  ssh -T -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
  "ODOO_SSH_USER='${ODOO_SSH_USER}' bash -s" > "${RAW_FILE}" 2>&1 <<'REMOTE'

set -euo pipefail

BASE_DIR="/home/${ODOO_SSH_USER}/odoo_watchdog"
SEND_FILE="${BASE_DIR}/send_alert.sh"
BACKUP_FILE="${BASE_DIR}/send_alert.sh.phase99.bak"

if ! grep -q 'failed_queue' "${SEND_FILE}"; then
  cp "${SEND_FILE}" "${BACKUP_FILE}"

  python3 - <<'PY'
from pathlib import Path
import os

user = os.environ["ODOO_SSH_USER"]
p = Path(f"/home/{user}/odoo_watchdog/send_alert.sh")
txt = p.read_text()

old = 'LOG_DIR="${BASE_DIR}/logs"\nmkdir -p "${LOG_DIR}"'
new = 'LOG_DIR="${BASE_DIR}/logs"\nFAILED_DIR="${LOG_DIR}/failed_queue"\nmkdir -p "${LOG_DIR}" "${FAILED_DIR}"'
if old not in txt:
    raise SystemExit("bloco LOG_DIR nao encontrado")
txt = txt.replace(old, new, 1)

old2 = 'OUT_JSON="${LOG_DIR}/alert_delivery_${TS}.json"'
new2 = 'OUT_JSON="${LOG_DIR}/alert_delivery_${TS}.json"\nFALLBACK_JSON="${FAILED_DIR}/alert_failed_${TS}.json"'
if old2 not in txt:
    raise SystemExit("bloco OUT_JSON nao encontrado")
txt = txt.replace(old2, new2, 1)

marker = 'cat "${OUT_JSON}"'
insert = '''if jq -e '.alert_delivery.http_ok == false' "${OUT_JSON}" >/dev/null; then
  cp "${OUT_JSON}" "${FALLBACK_JSON}"
fi

cat "${OUT_JSON}"'''
if marker not in txt:
    raise SystemExit("marker cat OUT_JSON nao encontrado")
txt = txt.replace(marker, insert, 1)

p.write_text(txt)
print("[OK] phase99 fallback aplicado")
PY
else
  [ -f "${BACKUP_FILE}" ] || cp "${SEND_FILE}" "${BACKUP_FILE}"
  echo "[OK] phase99 fallback ja estava aplicado"
fi

chmod 700 "${SEND_FILE}"

echo '===== SEND FILE ====='
ls -l "${SEND_FILE}"
echo
echo '===== BACKUP FILE ====='
ls -l "${BACKUP_FILE}"
echo
echo '===== FALLBACK CHECK ====='
grep -n 'failed_queue' "${SEND_FILE}" || true
REMOTE
SSH_RC=$?

SCRIPT_OK=false
BACKUP_OK=false
FALLBACK_OK=false

grep -q 'send_alert.sh' "${RAW_FILE}" && SCRIPT_OK=true || true
grep -q 'phase99.bak' "${RAW_FILE}" && BACKUP_OK=true || true
grep -q 'failed_queue' "${RAW_FILE}" && FALLBACK_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson script_ok "${SCRIPT_OK}" \
  --argjson backup_ok "${BACKUP_OK}" \
  --argjson fallback_ok "${FALLBACK_OK}" \
  '{
    created_at: $created_at,
    fallback_apply: {
      raw_file: $raw_file,
      script_ok: $script_ok,
      backup_ok: $backup_ok,
      fallback_ok: $fallback_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 99 — ODOO Alert Fallback Apply

## Apply
- raw_file: ${RAW_FILE}
- script_ok: ${SCRIPT_OK}
- backup_ok: ${BACKUP_OK}
- fallback_ok: ${FALLBACK_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] fallback apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
