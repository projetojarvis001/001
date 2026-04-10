#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/monitoring_infra_probe_${TS}.txt"
OUT_JSON="logs/executive/phase90_odoo_monitoring_infra_probe_${TS}.json"
OUT_MD="docs/generated/phase90_odoo_monitoring_infra_probe_${TS}.md"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
echo '===== ODOO_ACTIVE ====='
echo '${ODOO_SSH_PASS}' | sudo -S systemctl is-active odoo 2>/dev/null || true

echo
echo '===== NGINX_ACTIVE ====='
echo '${ODOO_SSH_PASS}' | sudo -S systemctl is-active nginx 2>/dev/null || true

echo
echo '===== PG_ACTIVE ====='
echo '${ODOO_SSH_PASS}' | sudo -S systemctl is-active postgresql 2>/dev/null || true

echo
echo '===== LISTEN ====='
echo '${ODOO_SSH_PASS}' | sudo -S ss -ltnp 2>/dev/null | grep -E ':8069|:8070|:5432|nginx|python|postgres' || true

echo
echo '===== CURL_LOCAL_NGINX ====='
curl -I -s http://127.0.0.1:8069 | sed -n '1,20p' || true

echo
echo '===== CURL_LOCAL_ODOO ====='
curl -I -s http://127.0.0.1:8070 | sed -n '1,20p' || true
" > "${RAW_FILE}"

ODOO_ACTIVE=false
NGINX_ACTIVE=false
PG_ACTIVE=false
HAS_NGINX_8069=false
HAS_ODOO_8070=false
HAS_PG_LOCAL=false

grep -A1 '^===== ODOO_ACTIVE =====' "${RAW_FILE}" | grep -q '^active$' && ODOO_ACTIVE=true || true
grep -A1 '^===== NGINX_ACTIVE =====' "${RAW_FILE}" | grep -q '^active$' && NGINX_ACTIVE=true || true
grep -A1 '^===== PG_ACTIVE =====' "${RAW_FILE}" | grep -q '^active$' && PG_ACTIVE=true || true

grep -q 'nginx' "${RAW_FILE}" && grep -q ':8069' "${RAW_FILE}" && HAS_NGINX_8069=true || true
grep -q 'python3' "${RAW_FILE}" && grep -q ':8070' "${RAW_FILE}" && HAS_ODOO_8070=true || true
grep -q 'postgres' "${RAW_FILE}" && grep -q '127.0.0.1:5432' "${RAW_FILE}" && HAS_PG_LOCAL=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson odoo_active "${ODOO_ACTIVE}" \
  --argjson nginx_active "${NGINX_ACTIVE}" \
  --argjson pg_active "${PG_ACTIVE}" \
  --argjson has_nginx_8069 "${HAS_NGINX_8069}" \
  --argjson has_odoo_8070 "${HAS_ODOO_8070}" \
  --argjson has_pg_local "${HAS_PG_LOCAL}" \
  '{
    created_at: $created_at,
    infra_probe: {
      raw_file: $raw_file,
      odoo_active: $odoo_active,
      nginx_active: $nginx_active,
      pg_active: $pg_active,
      has_nginx_8069: $has_nginx_8069,
      has_odoo_8070: $has_odoo_8070,
      has_pg_local: $has_pg_local
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 90A — ODOO Monitoring Infra Probe Fix

## Probe
- raw_file: ${RAW_FILE}
- odoo_active: ${ODOO_ACTIVE}
- nginx_active: ${NGINX_ACTIVE}
- pg_active: ${PG_ACTIVE}
- has_nginx_8069: ${HAS_NGINX_8069}
- has_odoo_8070: ${HAS_ODOO_8070}
- has_pg_local: ${HAS_PG_LOCAL}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] monitoring infra probe 90A gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
