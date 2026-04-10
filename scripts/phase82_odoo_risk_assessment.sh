#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase82_odoo_risk_assessment_${TS}.json"
OUT_MD="docs/generated/phase82_odoo_risk_assessment_${TS}.md"

PROBE_FILE="$(ls -1t logs/executive/phase82_odoo_remote_hardening_probe_*.json 2>/dev/null | head -n 1 || true)"
APP_FILE="$(ls -1t logs/executive/phase81_odoo_app_probe_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${PROBE_FILE}" ] || [ -z "${APP_FILE}" ]; then
  echo "[ERRO] probe files nao encontrados"
  exit 1
fi

HAS_ADMIN_PASSWD="$(jq -r '.hardening_probe.has_admin_passwd // false' "${PROBE_FILE}")"
HAS_PROXY_MODE="$(jq -r '.hardening_probe.has_proxy_mode // false' "${PROBE_FILE}")"
HAS_DBFILTER="$(jq -r '.hardening_probe.has_dbfilter // false' "${PROBE_FILE}")"
HAS_58069="$(jq -r '.hardening_probe.has_58069 // false' "${PROBE_FILE}")"
HAS_8069="$(jq -r '.hardening_probe.has_8069 // false' "${PROBE_FILE}")"
HAS_5432="$(jq -r '.hardening_probe.has_5432 // false' "${PROBE_FILE}")"
AUTH_OK="$(jq -r '.app_probe.auth_ok // false' "${APP_FILE}")"

RISK_SCORE=0
[ "${HAS_ADMIN_PASSWD}" = "true" ] && RISK_SCORE=$((RISK_SCORE + 1))
[ "${HAS_PROXY_MODE}" = "false" ] && RISK_SCORE=$((RISK_SCORE + 2))
[ "${HAS_DBFILTER}" = "false" ] && RISK_SCORE=$((RISK_SCORE + 2))
[ "${HAS_58069}" = "true" ] && RISK_SCORE=$((RISK_SCORE + 2))
[ "${HAS_8069}" = "true" ] && RISK_SCORE=$((RISK_SCORE + 2))
[ "${HAS_5432}" = "true" ] && RISK_SCORE=$((RISK_SCORE + 2))
[ "${AUTH_OK}" = "true" ] && RISK_SCORE=$((RISK_SCORE + 1))

RISK_LEVEL="LOW"
if [ "${RISK_SCORE}" -ge 4 ]; then RISK_LEVEL="MEDIUM"; fi
if [ "${RISK_SCORE}" -ge 7 ]; then RISK_LEVEL="HIGH"; fi
if [ "${RISK_SCORE}" -ge 10 ]; then RISK_LEVEL="CRITICAL"; fi

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg probe_file "${PROBE_FILE}" \
  --arg app_file "${APP_FILE}" \
  --argjson has_admin_passwd "${HAS_ADMIN_PASSWD}" \
  --argjson has_proxy_mode "${HAS_PROXY_MODE}" \
  --argjson has_dbfilter "${HAS_DBFILTER}" \
  --argjson has_58069 "${HAS_58069}" \
  --argjson has_8069 "${HAS_8069}" \
  --argjson has_5432 "${HAS_5432}" \
  --argjson auth_ok "${AUTH_OK}" \
  --argjson risk_score "${RISK_SCORE}" \
  --arg risk_level "${RISK_LEVEL}" \
  '{
    created_at: $created_at,
    risk: {
      probe_file: $probe_file,
      app_file: $app_file,
      has_admin_passwd: $has_admin_passwd,
      has_proxy_mode: $has_proxy_mode,
      has_dbfilter: $has_dbfilter,
      has_58069: $has_58069,
      has_8069: $has_8069,
      has_5432: $has_5432,
      auth_ok: $auth_ok,
      risk_score: $risk_score,
      risk_level: $risk_level
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 82 — ODOO Risk Assessment

## Risk
- has_admin_passwd: ${HAS_ADMIN_PASSWD}
- has_proxy_mode: ${HAS_PROXY_MODE}
- has_dbfilter: ${HAS_DBFILTER}
- has_58069: ${HAS_58069}
- has_8069: ${HAS_8069}
- has_5432: ${HAS_5432}
- auth_ok: ${AUTH_OK}
- risk_score: ${RISK_SCORE}
- risk_level: ${RISK_LEVEL}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] risk assessment gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
