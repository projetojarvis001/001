#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase101_watchdog_drift_rebaseline_${TS}.txt"
OUT_JSON="logs/executive/phase101_odoo_watchdog_drift_rebaseline_capture_${TS}.json"
OUT_MD="docs/generated/phase101_odoo_watchdog_drift_rebaseline_capture_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

sshpass -p "${ODOO_SSH_PASS}" \
  ssh -T -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
  "ODOO_SSH_USER='${ODOO_SSH_USER}' bash -s" > "${RAW_FILE}" 2>&1 <<'REMOTE'
set -euo pipefail

BASE_DIR="/home/${ODOO_SSH_USER}/odoo_watchdog"
LOG_DIR="${BASE_DIR}/logs"

SEND_SHA="$(sha256sum "${BASE_DIR}/send_alert.sh" | awk '{print $1}')"
ENV_SHA="$(sha256sum "${BASE_DIR}/alert.env" | awk '{print $1}')"
RETENTION_FILE="$(find "${BASE_DIR}" -maxdepth 1 -type f | grep 'retention' | head -n 1 || true)"
RETENTION_SHA=""
[ -n "${RETENTION_FILE}" ] && RETENTION_SHA="$(sha256sum "${RETENTION_FILE}" | awk '{print $1}')"

CRON_TMP="$(mktemp)"
crontab -l > "${CRON_TMP}" 2>/dev/null || true

echo '===== BASE DIR ====='
echo "${BASE_DIR}"
echo
echo '===== SEND SHA ====='
echo "${SEND_SHA}"
echo
echo '===== ENV SHA ====='
echo "${ENV_SHA}"
echo
echo '===== RETENTION FILE ====='
echo "${RETENTION_FILE}"
echo
echo '===== RETENTION SHA ====='
echo "${RETENTION_SHA}"
echo
echo '===== CRONTAB ====='
cat "${CRON_TMP}"
echo
echo '===== LAST RUN JSON ====='
[ -f "${LOG_DIR}/last_run.json" ] && cat "${LOG_DIR}/last_run.json"

rm -f "${CRON_TMP}"
REMOTE

BASE_DIR="$(awk '/===== BASE DIR =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
SEND_SHA="$(awk '/===== SEND SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
ENV_SHA="$(awk '/===== ENV SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
RETENTION_FILE="$(awk '/===== RETENTION FILE =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
RETENTION_SHA="$(awk '/===== RETENTION SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

CRON_WATCHDOG=false
CRON_RETENTION=false
LAST_JSON_OK=false

grep -q 'odoo_watchdog/watchdog_run.sh' "${RAW_FILE}" && CRON_WATCHDOG=true || true
grep -q 'retention' "${RAW_FILE}" && CRON_RETENTION=true || true
grep -q '"overall_ok": true' "${RAW_FILE}" && LAST_JSON_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg base_dir "${BASE_DIR}" \
  --arg send_sha "${SEND_SHA}" \
  --arg env_sha "${ENV_SHA}" \
  --arg retention_file "${RETENTION_FILE}" \
  --arg retention_sha "${RETENTION_SHA}" \
  --argjson cron_watchdog "${CRON_WATCHDOG}" \
  --argjson cron_retention "${CRON_RETENTION}" \
  --argjson last_json_ok "${LAST_JSON_OK}" \
  '{
    created_at: $created_at,
    drift_rebaseline: {
      raw_file: $raw_file,
      base_dir: $base_dir,
      send_sha: $send_sha,
      env_sha: $env_sha,
      retention_file: $retention_file,
      retention_sha: $retention_sha,
      cron_watchdog: $cron_watchdog,
      cron_retention: $cron_retention,
      last_json_ok: $last_json_ok,
      overall_ok: (
        ($send_sha != "") and
        ($env_sha != "") and
        ($retention_sha != "") and
        $cron_watchdog and
        $cron_retention and
        $last_json_ok
      )
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 101 — ODOO Drift Rebaseline Capture

## Baseline
- raw_file: ${RAW_FILE}
- base_dir: ${BASE_DIR}
- send_sha: ${SEND_SHA}
- env_sha: ${ENV_SHA}
- retention_file: ${RETENTION_FILE}
- retention_sha: ${RETENTION_SHA}
- cron_watchdog: ${CRON_WATCHDOG}
- cron_retention: ${CRON_RETENTION}
- last_json_ok: ${LAST_JSON_OK}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift rebaseline capture gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
