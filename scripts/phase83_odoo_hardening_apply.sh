#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/hardening_apply_${TS}.txt"
OUT_JSON="logs/executive/phase83_odoo_hardening_apply_${TS}.json"
OUT_MD="docs/generated/phase83_odoo_hardening_apply_${TS}.md"

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
CONF_FILE='/etc/odoo.conf'

if [ ! -f \"\${CONF_FILE}\" ]; then
  echo '[ERRO] /etc/odoo.conf nao encontrado'
  exit 1
fi

BACKUP_FILE=\"/etc/odoo.conf.bak.phase83.${TS}\"

printf '%s\n' '${SSH_PASS}' | \$SUDO cp \"\${CONF_FILE}\" \"\${BACKUP_FILE}\"

cat > /tmp/phase83_odoo_conf_patch.py <<PY
from pathlib import Path
conf = Path('/etc/odoo.conf')
txt = conf.read_text()

lines = txt.splitlines()
found_proxy = False
found_dbfilter = False
new_lines = []

for line in lines:
    stripped = line.strip()
    if stripped.startswith('proxy_mode'):
        new_lines.append('proxy_mode = True')
        found_proxy = True
    elif stripped.startswith('dbfilter'):
        new_lines.append('dbfilter = ^${DB}$')
        found_dbfilter = True
    else:
        new_lines.append(line)

if not found_proxy:
    new_lines.append('proxy_mode = True')
if not found_dbfilter:
    new_lines.append('dbfilter = ^${DB}$')

conf.write_text('\n'.join(new_lines) + '\n')
print('[OK] odoo.conf atualizado')
PY

printf '%s\n' '${SSH_PASS}' | \$SUDO python3 /tmp/phase83_odoo_conf_patch.py
rm -f /tmp/phase83_odoo_conf_patch.py

echo '===== BACKUP FILE ====='
echo \"\${BACKUP_FILE}\"

echo
echo '===== SAFE CONF VIEW ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO sed -n '1,220p' \"\${CONF_FILE}\" | \
  sed -E 's/^(admin_passwd[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I' | \
  sed -E 's/^(db_password[[:space:]]*=[[:space:]]*).*/\1[REDACTED]/I'

echo
echo '===== RESTART ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo 2>/dev/null || \
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl restart odoo-server 2>/dev/null || true
sleep 3

echo
echo '===== STATUS ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status odoo 2>/dev/null | sed -n '1,20p' || true
printf '%s\n' '${SSH_PASS}' | \$SUDO systemctl status odoo-server 2>/dev/null | sed -n '1,20p' || true

echo
echo '===== PORT CHECK ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei '8069|5432' || true
" > "${RAW_FILE}"

BACKUP_FILE="$(awk '/===== BACKUP FILE =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
PROXY_MODE_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^proxy_mode = True$' && PROXY_MODE_SET=true || true
DBFILTER_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q "^dbfilter = ^${DB}\$$" && DBFILTER_SET=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg backup_file "${BACKUP_FILE}" \
  --arg db "${DB}" \
  --argjson proxy_mode_set "${PROXY_MODE_SET}" \
  --argjson dbfilter_set "${DBFILTER_SET}" \
  '{
    created_at: $created_at,
    apply: {
      raw_file: $raw_file,
      backup_file: $backup_file,
      db: $db,
      proxy_mode_set: $proxy_mode_set,
      dbfilter_set: $dbfilter_set
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 83 — ODOO Hardening Apply

## Apply
- raw_file: ${RAW_FILE}
- backup_file: ${BACKUP_FILE}
- db: ${DB}
- proxy_mode_set: ${PROXY_MODE_SET}
- dbfilter_set: ${DBFILTER_SET}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] hardening apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
