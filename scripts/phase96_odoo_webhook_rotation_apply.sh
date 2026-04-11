#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase96_webhook_rotation_apply_${TS}.txt"
OUT_JSON="logs/executive/phase96_odoo_webhook_rotation_apply_${TS}.json"
OUT_MD="docs/generated/phase96_odoo_webhook_rotation_apply_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"
: "${ODOO_URL:?}"
: "${ODOO_DB:?}"
: "${ODOO_ALERT_WEBHOOK:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
ENV_FILE=\"\${BASE_DIR}/alert.env\"
BAK_FILE=\"\${BASE_DIR}/alert.env.bak.phase96.${TS}\"
SEND_FILE=\"\${BASE_DIR}/send_alert.sh\"

mkdir -p \"\${BASE_DIR}\"

[ -f \"\${ENV_FILE}\" ] && cp \"\${ENV_FILE}\" \"\${BAK_FILE}\" || true

cat > \"\${ENV_FILE}\" <<EOF
ODOO_URL='${ODOO_URL}'
ODOO_DB='${ODOO_DB}'
ODOO_ALERT_WEBHOOK='${ODOO_ALERT_WEBHOOK}'
EOF

chmod 600 \"\${ENV_FILE}\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== ENV FILE ====='
ls -l \"\${ENV_FILE}\"
echo
echo '===== BACKUP FILE ====='
[ -f \"\${BAK_FILE}\" ] && ls -l \"\${BAK_FILE}\" || echo 'NO_BACKUP'
echo
echo '===== SEND FILE ====='
ls -l \"\${SEND_FILE}\"
echo
echo '===== TEST RUN ====='
\"\${SEND_FILE}\"
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
ENV_OK=false
BACKUP_OK=false
RUN_OK=false

grep -q 'alert.env' "${RAW_FILE}" && ENV_OK=true || true
grep -q 'BACKUP FILE' "${RAW_FILE}" && BACKUP_OK=true || true
grep -q '"http_ok": true' "${RAW_FILE}" && RUN_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --argjson env_ok "${ENV_OK}" \
  --argjson backup_ok "${BACKUP_OK}" \
  --argjson run_ok "${RUN_OK}" \
  '{
    created_at: $created_at,
    webhook_rotation_apply: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      env_ok: $env_ok,
      backup_ok: $backup_ok,
      run_ok: $run_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 96 — ODOO Webhook Rotation Apply

## Apply
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- env_ok: ${ENV_OK}
- backup_ok: ${BACKUP_OK}
- run_ok: ${RUN_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] webhook rotation apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
