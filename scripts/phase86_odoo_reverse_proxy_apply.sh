#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/reverse_proxy_apply_${TS}.txt"
OUT_JSON="logs/executive/phase86_odoo_reverse_proxy_apply_${TS}.json"
OUT_MD="docs/generated/phase86_odoo_reverse_proxy_apply_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
SSH_PASS="${ODOO_SSH_PASS:-}"
DB="${ODOO_DB:-WPS}"

if [ -z "${HOST}" ] || [ -z "${SSH_USER}" ] || [ -z "${SSH_PASS}" ]; then
  echo "[ERRO] variaveis SSH do ODOO incompletas"
  exit 1
fi

sshpass -p "${SSH_PASS}" ssh -tt -o StrictHostKeyChecking=no -p "${PORT}" "${SSH_USER}@${HOST}" "
set -e

SUDO='sudo -S'
ODOO_CONF='/etc/odoo.conf'
NGINX_CONF='/etc/nginx/conf.d/odoo_phase86.conf'
ODOO_BAK='/etc/odoo.conf.bak.phase86.${TS}'
NGINX_BAK='/etc/nginx/conf.d/odoo_phase86.conf.bak.phase86.${TS}'

echo '===== PRECHECK ====='
command -v nginx >/dev/null 2>&1 || { echo '[ERRO] nginx nao encontrado'; exit 1; }
[ -f \"\${ODOO_CONF}\" ] || { echo '[ERRO] /etc/odoo.conf nao encontrado'; exit 1; }

printf '%s\n' '${SSH_PASS}' | \$SUDO cp \"\${ODOO_CONF}\" \"\${ODOO_BAK}\"
if printf '%s\n' '${SSH_PASS}' | \$SUDO test -f \"\${NGINX_CONF}\"; then
  printf '%s\n' '${SSH_PASS}' | \$SUDO cp \"\${NGINX_CONF}\" \"\${NGINX_BAK}\"
fi

cat > /tmp/phase86_patch_odoo.py <<PY
from pathlib import Path
conf = Path('/etc/odoo.conf')
txt = conf.read_text()

rules = {
    'proxy_mode': 'proxy_mode = True',
    'dbfilter': 'dbfilter = ^${DB}$',
    'list_db': 'list_db = False',
    'http_interface': 'http_interface = 127.0.0.1',
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
print('[OK] odoo.conf phase86 atualizado')
PY

printf '%s\n' '${SSH_PASS}' | \$SUDO python3 /tmp/phase86_patch_odoo.py
rm -f /tmp/phase86_patch_odoo.py

cat > /tmp/odoo_phase86.conf <<'NGINX'
server {
    listen 58069 default_server;
    listen [::]:58069 default_server;
    server_name _;

    client_max_body_size 64m;
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;
    }
}
NGINX

printf '%s\n' '${SSH_PASS}' | \$SUDO mv /tmp/odoo_phase86.conf \"\${NGINX_CONF}\"

echo '===== BACKUPS ====='
echo \"ODOO_BAK=\${ODOO_BAK}\"
echo \"NGINX_BAK=\${NGINX_BAK}\"

echo
echo '===== SAFE ODOO CONF ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' \"\${ODOO_CONF}\" | \
  sed -E 's/^(admin_passwd[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I' | \
  sed -E 's/^(db_password[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I'

echo
echo '===== NGINX CONF ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' \"\${NGINX_CONF}\"

echo
echo '===== NGINX TEST ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO nginx -t

echo
echo '===== RESTART SERVICES ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo 2>/dev/null || printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo-server 2>/dev/null || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart nginx
sleep 4

echo
echo '===== STATUS ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status nginx 2>/dev/null | sed -n '1,20p' || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status odoo 2>/dev/null | sed -n '1,20p' || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status odoo-server 2>/dev/null | sed -n '1,20p' || true

echo
echo '===== LISTEN ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei ':58069|:8069|:5432' || true
" > "${RAW_FILE}"

ODOO_BAK="$(awk -F= '/^ODOO_BAK=/{print $2; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
NGINX_BAK="$(awk -F= '/^NGINX_BAK=/{print $2; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"

PROXY_MODE_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^proxy_mode = True$' && PROXY_MODE_SET=true || true

LIST_DB_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^list_db = False$' && LIST_DB_SET=true || true

DBFILTER_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^dbfilter = ^WPS$' && DBFILTER_SET=true || true

HTTP_INTERFACE_LOCAL=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^http_interface = 127.0.0.1$' && HTTP_INTERFACE_LOCAL=true || true

NGINX_TEST_OK=false
tr -d '\r' < "${RAW_FILE}" | grep -q 'test is successful' && NGINX_TEST_OK=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg odoo_backup "${ODOO_BAK}" \
  --arg nginx_backup "${NGINX_BAK}" \
  --argjson proxy_mode_set "${PROXY_MODE_SET}" \
  --argjson list_db_set "${LIST_DB_SET}" \
  --argjson dbfilter_set "${DBFILTER_SET}" \
  --argjson http_interface_local "${HTTP_INTERFACE_LOCAL}" \
  --argjson nginx_test_ok "${NGINX_TEST_OK}" \
  '{
    created_at: $created_at,
    apply: {
      raw_file: $raw_file,
      odoo_backup: $odoo_backup,
      nginx_backup: $nginx_backup,
      proxy_mode_set: $proxy_mode_set,
      list_db_set: $list_db_set,
      dbfilter_set: $dbfilter_set,
      http_interface_local: $http_interface_local,
      nginx_test_ok: $nginx_test_ok
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 86 — ODOO Reverse Proxy Apply

## Apply
- raw_file: ${RAW_FILE}
- odoo_backup: ${ODOO_BAK}
- nginx_backup: ${NGINX_BAK}
- proxy_mode_set: ${PROXY_MODE_SET}
- list_db_set: ${LIST_DB_SET}
- dbfilter_set: ${DBFILTER_SET}
- http_interface_local: ${HTTP_INTERFACE_LOCAL}
- nginx_test_ok: ${NGINX_TEST_OK}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] reverse proxy apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
