#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/proxy_rewire_apply_86b_${TS}.txt"
OUT_JSON="logs/executive/phase86b_odoo_proxy_rewire_apply_${TS}.json"
OUT_MD="docs/generated/phase86b_odoo_proxy_rewire_apply_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
SSH_PASS="${ODOO_SSH_PASS:-}"
DB="${ODOO_DB:-WPS}"

sshpass -p "${SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${PORT}" "${SSH_USER}@${HOST}" "
set -e

SUDO='sudo -S'
ODOO_CONF='/etc/odoo.conf'
ODOO_BAK='/etc/odoo.conf.bak.phase86b.${TS}'
NGINX_SITE='/etc/nginx/sites-available/odoo_phase86b'
NGINX_LINK='/etc/nginx/sites-enabled/odoo_phase86b'

echo '===== PRECHECK ====='
command -v nginx >/dev/null 2>&1 || { echo '[ERRO] nginx nao encontrado'; exit 1; }
[ -f \"\${ODOO_CONF}\" ] || { echo '[ERRO] /etc/odoo.conf nao encontrado'; exit 1; }

printf '%s\n' '${SSH_PASS}' | \$SUDO cp \"\${ODOO_CONF}\" \"\${ODOO_BAK}\"

cat > /tmp/phase86b_patch_odoo.py <<PY
from pathlib import Path
conf = Path('/etc/odoo.conf')
txt = conf.read_text()

rules = {
    'proxy_mode': 'proxy_mode = True',
    'dbfilter': 'dbfilter = ^${DB}$',
    'list_db': 'list_db = False',
    'http_interface': 'http_interface = 127.0.0.1',
    'xmlrpc_port': 'xmlrpc_port = 8070',
}

lines = txt.splitlines()
seen = {k: False for k in rules}
new_lines = []

for line in lines:
    stripped = line.strip()
    replaced = False
    for key, value in rules.items():
        if stripped.startswith(key):
            new_lines.append(value)
            seen[key] = True
            replaced = True
            break
    if not replaced:
        new_lines.append(line)

for key, value in rules.items():
    if not seen[key]:
        new_lines.append(value)

conf.write_text('\\n'.join(new_lines) + '\\n')
print('[OK] odoo.conf phase86b atualizado')
PY

printf '%s\n' '${SSH_PASS}' | \$SUDO python3 /tmp/phase86b_patch_odoo.py
rm -f /tmp/phase86b_patch_odoo.py

cat > /tmp/odoo_phase86b.conf <<'NGINX'
server {
    listen 8069 default_server;
    listen [::]:8069 default_server;
    server_name _;

    client_max_body_size 64m;
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location / {
        proxy_pass http://127.0.0.1:8070;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_redirect off;
    }
}
NGINX

printf '%s\n' '${SSH_PASS}' | \$SUDO mv /tmp/odoo_phase86b.conf \"\${NGINX_SITE}\"
printf '%s\n' '${SSH_PASS}' | \$SUDO ln -sf \"\${NGINX_SITE}\" \"\${NGINX_LINK}\"
printf '%s\n' '${SSH_PASS}' | \$SUDO rm -f /etc/nginx/sites-enabled/default
printf '%s\n' '${SSH_PASS}' | \$SUDO rm -f /etc/nginx/sites-enabled/odoo_phase86a
printf '%s\n' '${SSH_PASS}' | \$SUDO rm -f /etc/nginx/sites-available/odoo_phase86a

echo '===== BACKUP ====='
echo \"ODOO_BAK=\${ODOO_BAK}\"

echo
echo '===== SAFE ODOO CONF ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' \"\${ODOO_CONF}\" | \
  sed -E 's/^(admin_passwd[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I' | \
  sed -E 's/^(db_password[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I'

echo
echo '===== NGINX SITE ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' \"\${NGINX_SITE}\"

echo
echo '===== NGINX TEST ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO nginx -t

echo
echo '===== RESTART ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo 2>/dev/null || printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo-server 2>/dev/null || true
sleep 3
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart nginx
sleep 4

echo
echo '===== STATUS ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status nginx 2>/dev/null | sed -n '1,20p' || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status odoo 2>/dev/null | sed -n '1,20p' || true

echo
echo '===== LISTEN ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei ':8069|:8070|:5432' || true
" > "${RAW_FILE}"

ODOO_BAK="$(awk -F= '/^ODOO_BAK=/{print $2; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

XMLRPC_8070_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^xmlrpc_port = 8070$' && XMLRPC_8070_SET=true || true

HTTP_INTERFACE_LOCAL=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^http_interface = 127.0.0.1$' && HTTP_INTERFACE_LOCAL=true || true

NGINX_TEST_OK=false
tr -d '\r' < "${RAW_FILE}" | grep -q 'test is successful' && NGINX_TEST_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg odoo_backup "${ODOO_BAK}" \
  --argjson xmlrpc_8070_set "${XMLRPC_8070_SET}" \
  --argjson http_interface_local "${HTTP_INTERFACE_LOCAL}" \
  --argjson nginx_test_ok "${NGINX_TEST_OK}" \
  '{
    created_at: $created_at,
    apply: {
      raw_file: $raw_file,
      odoo_backup: $odoo_backup,
      xmlrpc_8070_set: $xmlrpc_8070_set,
      http_interface_local: $http_interface_local,
      nginx_test_ok: $nginx_test_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 86B — ODOO Proxy Rewire Apply

## Apply
- raw_file: ${RAW_FILE}
- odoo_backup: ${ODOO_BAK}
- xmlrpc_8070_set: ${XMLRPC_8070_SET}
- http_interface_local: ${HTTP_INTERFACE_LOCAL}
- nginx_test_ok: ${NGINX_TEST_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] proxy rewire apply 86B gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
