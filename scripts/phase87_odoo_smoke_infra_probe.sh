#!/usr/bin/env bash
set -euo pipefail

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/smoke_infra_probe_${TS}.txt"
OUT_JSON="logs/executive/phase87_odoo_smoke_infra_probe_${TS}.json"
OUT_MD="docs/generated/phase87_odoo_smoke_infra_probe_${TS}.md"

sshpass -p "${ODOO_SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${ODOO_PORT}" "${ODOO_SSH_USER}@${ODOO_HOST}" "
echo '===== LISTEN ====='
echo '${ODOO_SSH_PASS}' | sudo -S ss -ltnp 2>/dev/null | grep -E ':8069|:8070|:5432|nginx|python|postgres' || true

echo
echo '===== CURL LOCAL 8069 ====='
curl -I -s http://127.0.0.1:8069 | sed -n '1,20p' || true

echo
echo '===== CURL LOCAL 8070 ====='
curl -I -s http://127.0.0.1:8070 | sed -n '1,20p' || true

echo
echo '===== CURL PUBLIC 58069 ====='
curl -I -s http://177.104.176.69:58069 | sed -n '1,20p' || true
" > "${RAW_FILE}"

HAS_NGINX_8069=false
HAS_ODOO_8070=false
HAS_PG_LOCAL=true
PUBLIC_HAS_NGINX=false

grep -E '0\.0\.0\.0:8069.*nginx|\[::\]:8069.*nginx' "${RAW_FILE}" >/dev/null 2>&1 && HAS_NGINX_8069=true || true
grep -E '127\.0\.0\.1:8070.*python3' "${RAW_FILE}" >/dev/null 2>&1 && HAS_ODOO_8070=true || true
grep -E '127\.0\.0\.1:5432.*postgres' "${RAW_FILE}" >/dev/null 2>&1 || HAS_PG_LOCAL=false
grep -A10 '===== CURL PUBLIC 58069 =====' "${RAW_FILE}" | grep -qi 'Server: nginx' && PUBLIC_HAS_NGINX=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson has_nginx_8069 "${HAS_NGINX_8069}" \
  --argjson has_odoo_8070 "${HAS_ODOO_8070}" \
  --argjson has_pg_local "${HAS_PG_LOCAL}" \
  --argjson public_has_nginx "${PUBLIC_HAS_NGINX}" \
  '{
    created_at: $created_at,
    infra_probe: {
      raw_file: $raw_file,
      has_nginx_8069: $has_nginx_8069,
      has_odoo_8070: $has_odoo_8070,
      has_pg_local: $has_pg_local,
      public_has_nginx: $public_has_nginx
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 87 — ODOO Smoke Infra Probe

## Probe
- raw_file: ${RAW_FILE}
- has_nginx_8069: ${HAS_NGINX_8069}
- has_odoo_8070: ${HAS_ODOO_8070}
- has_pg_local: ${HAS_PG_LOCAL}
- public_has_nginx: ${PUBLIC_HAS_NGINX}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] smoke infra probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
