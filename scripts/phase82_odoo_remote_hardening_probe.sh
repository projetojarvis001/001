#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/hardening_probe_${TS}.txt"
OUT_JSON="logs/executive/phase82_odoo_remote_hardening_probe_${TS}.json"
OUT_MD="docs/generated/phase82_odoo_remote_hardening_probe_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
SSH_PASS="${ODOO_SSH_PASS:-}"

if [ -z "${HOST}" ] || [ -z "${SSH_USER}" ] || [ -z "${SSH_PASS}" ]; then
  echo "[ERRO] variaveis SSH do ODOO incompletas"
  exit 1
fi

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no -p "${PORT}" "${SSH_USER}@${HOST}" '
echo "===== ODOO CONF PATHS ====="
find /etc /opt /home /srv -maxdepth 4 -type f \( -name "odoo.conf" -o -name "*odoo*.conf" \) 2>/dev/null | head -n 30 || true
echo

CONF_FILE="$(find /etc /opt /home /srv -maxdepth 4 -type f \( -name "odoo.conf" -o -name "*odoo*.conf" \) 2>/dev/null | head -n 1 || true)"
echo "===== SELECTED CONF ====="
echo "${CONF_FILE}"
echo

if [ -n "${CONF_FILE}" ]; then
  echo "===== CONF SAFE VIEW ====="
  sed -n "1,220p" "${CONF_FILE}" 2>/dev/null | \
    sed -E "s/^(admin_passwd[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I" | \
    sed -E "s/^(db_password[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I"
  echo
fi

echo "===== SYSTEMD ODOO ====="
systemctl cat odoo 2>/dev/null || true
systemctl cat odoo-server 2>/dev/null || true
echo

echo "===== NGINX / APACHE ====="
find /etc/nginx /etc/apache2 -maxdepth 3 -type f 2>/dev/null | grep -Ei "nginx|sites-enabled|sites-available|apache" | head -n 50 || true
echo

echo "===== NGINX CONFIG HINTS ====="
grep -RniE "58069|8069|proxy_pass|server_name" /etc/nginx 2>/dev/null | head -n 80 || true
echo

echo "===== FIREWALL ====="
ufw status 2>/dev/null || true
iptables -S 2>/dev/null | head -n 80 || true
echo

echo "===== LISTEN PORTS ====="
ss -ltnp 2>/dev/null | grep -Ei "58069|8069|5432|80|443" || true
netstat -ltnp 2>/dev/null | grep -Ei "58069|8069|5432|80|443" || true
echo

echo "===== DB MANAGER CHECK HINT ====="
grep -RniE "list_db|admin_passwd|proxy_mode|dbfilter|xmlrpc|xmlrpc_interface|netrpc|longpolling_port" /etc /opt /home /srv 2>/dev/null | head -n 120 || true
' > "${RAW_FILE}"

CONF_FILE="$(awk '/===== SELECTED CONF =====/{getline; print; exit}' "${RAW_FILE}" | xargs || true)"
HAS_ADMIN_PASSWD=false
grep -qi 'admin_passwd' "${RAW_FILE}" && HAS_ADMIN_PASSWD=true || true
HAS_PROXY_MODE=false
grep -qi 'proxy_mode' "${RAW_FILE}" && HAS_PROXY_MODE=true || true
HAS_DBFILTER=false
grep -qi 'dbfilter' "${RAW_FILE}" && HAS_DBFILTER=true || true
HAS_NGINX_HINT=false
grep -qi 'proxy_pass' "${RAW_FILE}" && HAS_NGINX_HINT=true || true
HAS_58069=false
grep -q '58069' "${RAW_FILE}" && HAS_58069=true || true
HAS_8069=false
grep -q '8069' "${RAW_FILE}" && HAS_8069=true || true
HAS_5432=false
grep -q '5432' "${RAW_FILE}" && HAS_5432=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg conf_file "${CONF_FILE}" \
  --argjson has_admin_passwd "${HAS_ADMIN_PASSWD}" \
  --argjson has_proxy_mode "${HAS_PROXY_MODE}" \
  --argjson has_dbfilter "${HAS_DBFILTER}" \
  --argjson has_nginx_hint "${HAS_NGINX_HINT}" \
  --argjson has_58069 "${HAS_58069}" \
  --argjson has_8069 "${HAS_8069}" \
  --argjson has_5432 "${HAS_5432}" \
  '{
    created_at: $created_at,
    hardening_probe: {
      raw_file: $raw_file,
      conf_file: $conf_file,
      has_admin_passwd: $has_admin_passwd,
      has_proxy_mode: $has_proxy_mode,
      has_dbfilter: $has_dbfilter,
      has_nginx_hint: $has_nginx_hint,
      has_58069: $has_58069,
      has_8069: $has_8069,
      has_5432: $has_5432
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 82 — ODOO Remote Hardening Probe

## Probe
- raw_file: ${RAW_FILE}
- conf_file: ${CONF_FILE}
- has_admin_passwd: ${HAS_ADMIN_PASSWD}
- has_proxy_mode: ${HAS_PROXY_MODE}
- has_dbfilter: ${HAS_DBFILTER}
- has_nginx_hint: ${HAS_NGINX_HINT}
- has_58069: ${HAS_58069}
- has_8069: ${HAS_8069}
- has_5432: ${HAS_5432}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] remote hardening probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
