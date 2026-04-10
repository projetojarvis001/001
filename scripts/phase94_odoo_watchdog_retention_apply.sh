#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase94_remote_watchdog_retention_${TS}.txt"
OUT_JSON="logs/executive/phase94_odoo_watchdog_retention_apply_${TS}.json"
OUT_MD="docs/generated/phase94_odoo_watchdog_retention_apply_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
set -e

BASE_DIR='/home/${ODOO_SSH_USER}/odoo_watchdog'
LOG_DIR=\"\${BASE_DIR}/logs\"
RETENTION_FILE=\"\${BASE_DIR}/retention.sh\"
CRON_TMP=\"/tmp/odoo_watchdog_retention_${TS}.txt\"

mkdir -p \"\${LOG_DIR}\"

cat > \"\${RETENTION_FILE}\" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\" && pwd)\"
LOG_DIR=\"\${BASE_DIR}/logs\"
mkdir -p \"\${LOG_DIR}\"

find \"\${LOG_DIR}\" -type f -name 'watchdog_*.json' -mtime +7 -delete || true
find \"\${LOG_DIR}\" -type f -name 'watchdog_*.log' -mtime +7 -delete || true
find \"\${LOG_DIR}\" -type f -name 'cron_stdout.log' -size +5M -exec sh -c '> \"\$1\"' _ {} \; || true

JSON_COUNT=\$(find \"\${LOG_DIR}\" -type f -name 'watchdog_*.json' | wc -l | xargs)
LOG_COUNT=\$(find \"\${LOG_DIR}\" -type f -name 'watchdog_*.log' | wc -l | xargs)
CRON_SIZE=\$(du -b \"\${LOG_DIR}/cron_stdout.log\" 2>/dev/null | awk '{print \$1}' | xargs || echo 0)

printf 'json_count=%s\n' \"\${JSON_COUNT}\"
printf 'log_count=%s\n' \"\${LOG_COUNT}\"
printf 'cron_stdout_size=%s\n' \"\${CRON_SIZE}\"
EOF

chmod 700 \"\${RETENTION_FILE}\"

( crontab -l 2>/dev/null | grep -v 'odoo_watchdog/retention.sh' || true ) > \"\${CRON_TMP}\"
echo '17 2 * * * /home/${ODOO_SSH_USER}/odoo_watchdog/retention.sh >> /home/${ODOO_SSH_USER}/odoo_watchdog/logs/retention_stdout.log 2>&1' >> \"\${CRON_TMP}\"
crontab \"\${CRON_TMP}\"
rm -f \"\${CRON_TMP}\"

echo '===== BASE DIR ====='
echo \"\${BASE_DIR}\"
echo
echo '===== RETENTION FILE ====='
ls -l \"\${RETENTION_FILE}\"
echo
echo '===== RETENTION RUN ====='
\" \${RETENTION_FILE}\" 2>/dev/null || \"\${RETENTION_FILE}\"
echo
echo '===== CRONTAB ====='
crontab -l
" > "${RAW_FILE}" 2>&1

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
SCRIPT_OK=false
CRON_OK=false
RUN_OK=false

grep -q 'retention.sh' "${RAW_FILE}" && SCRIPT_OK=true || true
grep -q '17 2 \* \* \* /home/' "${RAW_FILE}" && CRON_OK=true || true
grep -q 'json_count=' "${RAW_FILE}" && RUN_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --argjson script_ok "${SCRIPT_OK}" \
  --argjson cron_ok "${CRON_OK}" \
  --argjson run_ok "${RUN_OK}" \
  '{
    created_at: $created_at,
    retention_apply: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      script_ok: $script_ok,
      cron_ok: $cron_ok,
      run_ok: $run_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 94 — ODOO Watchdog Retention Apply

## Apply
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- script_ok: ${SCRIPT_OK}
- cron_ok: ${CRON_OK}
- run_ok: ${RUN_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] retention apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
