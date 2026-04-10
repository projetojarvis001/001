#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/exposure_probe_${TS}.txt"
OUT_JSON="logs/executive/phase85_odoo_exposure_probe_${TS}.json"
OUT_MD="docs/generated/phase85_odoo_exposure_probe_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
SSH_PASS="${ODOO_SSH_PASS:-}"

if [ -z "${HOST}" ] || [ -z "${SSH_USER}" ] || [ -z "${SSH_PASS}" ]; then
  echo "[ERRO] variaveis SSH do ODOO incompletas"
  exit 1
fi

sshpass -p "${SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${PORT}" "${SSH_USER}@${HOST}" "
set -e

SUDO='sudo -S'

echo '===== HOSTNAME ====='
hostname || true

echo
echo '===== PUBLIC IP CHECK ====='
curl -4 -s ifconfig.me || true
echo

echo
echo '===== LISTEN PORTS ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei ':80 |:443 |:5432 |:58069 |:8069 ' || true

echo
echo '===== FULL LISTEN GREP ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei '80|443|5432|58069|8069|nginx|apache|haproxy|caddy|python|postgres' || true

echo
echo '===== IPTABLES ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO iptables -S 2>/dev/null || true

echo
echo '===== UFW ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ufw status numbered 2>/dev/null || true

echo
echo '===== NGINX SYSTEMD ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status nginx 2>/dev/null | sed -n '1,20p' || true

echo
echo '===== APACHE SYSTEMD ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status apache2 2>/dev/null | sed -n '1,20p' || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status httpd 2>/dev/null | sed -n '1,20p' || true

echo
echo '===== PROXY CONFIG FILES ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO find /etc/nginx /etc/apache2 /etc/httpd /etc/caddy /etc/haproxy -maxdepth 3 -type f 2>/dev/null | sort || true

echo
echo '===== GREP ODOO IN PROXY FILES ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO grep -RniE '8069|58069|proxy_pass|odoo|upstream' /etc/nginx /etc/apache2 /etc/httpd /etc/caddy /etc/haproxy 2>/dev/null || true

echo
echo '===== DOCKER ====='
docker ps --format '{{.Names}}|{{.Image}}|{{.Ports}}' 2>/dev/null || true

echo
echo '===== ODOO SERVICE FILE ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl cat odoo 2>/dev/null || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl cat odoo-server 2>/dev/null || true

echo
echo '===== ODOO CONF SAFE ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' /etc/odoo.conf 2>/dev/null | \
  sed -E 's/^(admin_passwd[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I' | \
  sed -E 's/^(db_password[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I' || true
" > "${RAW_FILE}"

HAS_8069_GLOBAL=false
tr -d '\r' < "${RAW_FILE}" | grep -Eq '0\.0\.0\.0:8069|:::8069' && HAS_8069_GLOBAL=true || true

HAS_5432_GLOBAL=false
tr -d '\r' < "${RAW_FILE}" | grep -Eq '0\.0\.0\.0:5432|:::5432' && HAS_5432_GLOBAL=true || true

HAS_5432_LOCAL=false
tr -d '\r' < "${RAW_FILE}" | grep -Eq '127\.0\.0\.1:5432|::1:5432|localhost:5432' && HAS_5432_LOCAL=true || true

NGINX_FOUND=false
tr -d '\r' < "${RAW_FILE}" | grep -qi 'nginx' && NGINX_FOUND=true || true

APACHE_FOUND=false
tr -d '\r' < "${RAW_FILE}" | grep -Eqi 'apache2|httpd' && APACHE_FOUND=true || true

PROXY_PASS_FOUND=false
tr -d '\r' < "${RAW_FILE}" | grep -qi 'proxy_pass' && PROXY_PASS_FOUND=true || true

HAS_58069_LISTEN=false
tr -d '\r' < "${RAW_FILE}" | grep -Eq ':58069' && HAS_58069_LISTEN=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --argjson has_8069_global "${HAS_8069_GLOBAL}" \
  --argjson has_5432_global "${HAS_5432_GLOBAL}" \
  --argjson has_5432_local "${HAS_5432_LOCAL}" \
  --argjson nginx_found "${NGINX_FOUND}" \
  --argjson apache_found "${APACHE_FOUND}" \
  --argjson proxy_pass_found "${PROXY_PASS_FOUND}" \
  --argjson has_58069_listen "${HAS_58069_LISTEN}" \
  '{
    created_at: $created_at,
    exposure_probe: {
      raw_file: $raw_file,
      has_8069_global: $has_8069_global,
      has_5432_global: $has_5432_global,
      has_5432_local: $has_5432_local,
      nginx_found: $nginx_found,
      apache_found: $apache_found,
      proxy_pass_found: $proxy_pass_found,
      has_58069_listen: $has_58069_listen
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 85 — ODOO Exposure Probe

## Exposure
- raw_file: ${RAW_FILE}
- has_8069_global: ${HAS_8069_GLOBAL}
- has_5432_global: ${HAS_5432_GLOBAL}
- has_5432_local: ${HAS_5432_LOCAL}
- nginx_found: ${NGINX_FOUND}
- apache_found: ${APACHE_FOUND}
- proxy_pass_found: ${PROXY_PASS_FOUND}
- has_58069_listen: ${HAS_58069_LISTEN}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] exposure probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
