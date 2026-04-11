#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/phase101_watchdog_drift_rebaseline_probe_${TS}.txt"
OUT_JSON="logs/executive/phase101_odoo_watchdog_drift_rebaseline_probe_${TS}.json"
OUT_MD="docs/generated/phase101_odoo_watchdog_drift_rebaseline_probe_${TS}.md"

: "${ODOO_HOST:?}"
: "${ODOO_PORT:?}"
: "${ODOO_SSH_USER:?}"
: "${ODOO_SSH_PASS:?}"

BASELINE_FILE="$(ls -1t logs/executive/phase101_odoo_watchdog_drift_rebaseline_capture_*.json 2>/dev/null | head -n 1 || true)"
[ -n "${BASELINE_FILE}" ] || { echo "[ERRO] baseline 101 nao encontrada"; exit 1; }

BASE_SEND_SHA="$(jq -r '.drift_rebaseline.send_sha' "${BASELINE_FILE}")"
BASE_ENV_SHA="$(jq -r '.drift_rebaseline.env_sha' "${BASELINE_FILE}")"
BASE_RETENTION_SHA="$(jq -r '.drift_rebaseline.retention_sha' "${BASELINE_FILE}")"

sshpass -p "${ODOO_SSH_PASS}" \
  ssh -T -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" \
  "ODOO_SSH_USER='${ODOO_SSH_USER}' bash -s" > "${RAW_FILE}" 2>&1 <<'REMOTE'
set -euo pipefail

BASE_DIR="/home/${ODOO_SSH_USER}/odoo_watchdog"

SEND_SHA="$(sha256sum "${BASE_DIR}/send_alert.sh" | awk '{print $1}')"
ENV_SHA="$(sha256sum "${BASE_DIR}/alert.env" | awk '{print $1}')"
RETENTION_FILE="$(find "${BASE_DIR}" -maxdepth 1 -type f | grep 'retention' | head -n 1 || true)"
RETENTION_SHA=""
[ -n "${RETENTION_FILE}" ] && RETENTION_SHA="$(sha256sum "${RETENTION_FILE}" | awk '{print $1}')"

echo '===== CURRENT SEND SHA ====='
echo "${SEND_SHA}"
echo
echo '===== CURRENT ENV SHA ====='
echo "${ENV_SHA}"
echo
echo '===== CURRENT RETENTION SHA ====='
echo "${RETENTION_SHA}"
REMOTE

CURRENT_SEND_SHA="$(awk '/===== CURRENT SEND SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_ENV_SHA="$(awk '/===== CURRENT ENV SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
CURRENT_RETENTION_SHA="$(awk '/===== CURRENT RETENTION SHA =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

SEND_MATCH=false
ENV_MATCH=false
RETENTION_MATCH=false

[ "${CURRENT_SEND_SHA}" = "${BASE_SEND_SHA}" ] && SEND_MATCH=true || true
[ "${CURRENT_ENV_SHA}" = "${BASE_ENV_SHA}" ] && ENV_MATCH=true || true
[ "${CURRENT_RETENTION_SHA}" = "${BASE_RETENTION_SHA}" ] && RETENTION_MATCH=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg baseline_file "${BASELINE_FILE}" \
  --arg current_send_sha "${CURRENT_SEND_SHA}" \
  --arg current_env_sha "${CURRENT_ENV_SHA}" \
  --arg current_retention_sha "${CURRENT_RETENTION_SHA}" \
  --argjson send_match "${SEND_MATCH}" \
  --argjson env_match "${ENV_MATCH}" \
  --argjson retention_match "${RETENTION_MATCH}" \
  '{
    created_at: $created_at,
    drift_rebaseline_probe: {
      raw_file: $raw_file,
      baseline_file: $baseline_file,
      current_send_sha: $current_send_sha,
      current_env_sha: $current_env_sha,
      current_retention_sha: $current_retention_sha,
      send_match: $send_match,
      env_match: $env_match,
      retention_match: $retention_match,
      overall_ok: ($send_match and $env_match and $retention_match)
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 101 — ODOO Drift Rebaseline Probe

## Probe
- raw_file: ${RAW_FILE}
- baseline_file: ${BASELINE_FILE}
- current_send_sha: ${CURRENT_SEND_SHA}
- current_env_sha: ${CURRENT_ENV_SHA}
- current_retention_sha: ${CURRENT_RETENTION_SHA}
- send_match: ${SEND_MATCH}
- env_match: ${ENV_MATCH}
- retention_match: ${RETENTION_MATCH}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] drift rebaseline probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
