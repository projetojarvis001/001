#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/surface_reduce_apply_${TS}.txt"
OUT_JSON="logs/executive/phase84_odoo_surface_reduce_apply_${TS}.json"
OUT_MD="docs/generated/phase84_odoo_surface_reduce_apply_${TS}.md"

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
CONF_FILE='/etc/odoo.conf'

if [ ! -f \"\${CONF_FILE}\" ]; then
  echo '[ERRO] /etc/odoo.conf nao encontrado'
  exit 1
fi

BACKUP_FILE=\"/etc/odoo.conf.bak.phase84.${TS}\"
printf '%s\n' '${SSH_PASS}' | \$SUDO cp \"\${CONF_FILE}\" \"\${BACKUP_FILE}\"

cat > /tmp/phase84_odoo_conf_patch.py <<PY
from pathlib import Path
conf = Path('/etc/odoo.conf')
txt = conf.read_text()

lines = txt.splitlines()
found_list_db = False
new_lines = []

for line in lines:
    stripped = line.strip()
    if stripped.startswith('list_db'):
        new_lines.append('list_db = False')
        found_list_db = True
    else:
        new_lines.append(line)

if not found_list_db:
    new_lines.append('list_db = False')

conf.write_text('\\n'.join(new_lines) + '\\n')
print('[OK] odoo.conf atualizado na phase84')
PY

printf '%s\n' '${SSH_PASS}' | \$SUDO python3 /tmp/phase84_odoo_conf_patch.py
rm -f /tmp/phase84_odoo_conf_patch.py

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
printf '%s\n' '${SSH_PASS}' | \$SUDO ss -ltnp 2>/dev/null | grep -Ei '8069|5432|58069|80|443' || true

echo
echo '===== UFW ====='
printf '%s\n' '${SSH_PASS}' | \$SUDO ufw status 2>/dev/null || true
" > "${RAW_FILE}"

BACKUP_FILE="$(awk '/===== BACKUP FILE =====/{getline; print; exit}' "${RAW_FILE}" | tr -d '\r' | xargs || true)"
LIST_DB_SET=false
tr -d '\r' < "${RAW_FILE}" | grep -q '^list_db = False$' && LIST_DB_SET=true || true
HAS_8069=false
tr -d '\r' < "${RAW_FILE}" | grep -q '8069' && HAS_8069=true || true
HAS_5432=false
tr -d '\r' < "${RAW_FILE}" | grep -q '5432' && HAS_5432=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg backup_file "${BACKUP_FILE}" \
  --argjson list_db_set "${LIST_DB_SET}" \
  --argjson has_8069 "${HAS_8069}" \
  --argjson has_5432 "${HAS_5432}" \
  '{
    created_at: $created_at,
    apply: {
      raw_file: $raw_file,
      backup_file: $backup_file,
      list_db_set: $list_db_set,
      has_8069: $has_8069,
      has_5432: $has_5432
    },
    governance: {
      deploy_executed: true,
      production_changed: true
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 84 — ODOO Surface Reduction Apply

## Apply
- raw_file: ${RAW_FILE}
- backup_file: ${BACKUP_FILE}
- list_db_set: ${LIST_DB_SET}
- has_8069: ${HAS_8069}
- has_5432: ${HAS_5432}

## Governança
- deploy_executed: true
- production_changed: true
MD

echo "[OK] surface reduction apply gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
