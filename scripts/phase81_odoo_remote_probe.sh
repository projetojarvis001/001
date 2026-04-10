#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p runtime/odoo logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/remote_probe_${TS}.txt"
OUT_JSON="logs/executive/phase81_odoo_remote_probe_${TS}.json"
OUT_MD="docs/generated/phase81_odoo_remote_probe_${TS}.md"

HOST="${ODOO_HOST:-}"
PORT="${ODOO_PORT:-22}"
SSH_USER="${ODOO_SSH_USER:-}"
SSH_PASS="${ODOO_SSH_PASS:-}"

if [ -z "${HOST}" ] || [ -z "${SSH_USER}" ] || [ -z "${SSH_PASS}" ]; then
  echo "[ERRO] variaveis SSH do ODOO incompletas"
  exit 1
fi

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no -p "${PORT}" "${SSH_USER}@${HOST}" '
echo "===== HOSTNAME ====="
hostname || true
echo

echo "===== OS ====="
uname -a || true
cat /etc/os-release 2>/dev/null || true
echo

echo "===== UPTIME ====="
uptime || true
echo

echo "===== ODOO SERVICE ====="
systemctl status odoo 2>/dev/null | sed -n "1,20p" || true
systemctl status odoo-server 2>/dev/null | sed -n "1,20p" || true
echo

echo "===== ODOO PROCESS ====="
ps aux | grep -Ei "odoo|odoo-bin" | grep -v grep || true
echo

echo "===== POSTGRES PROCESS ====="
ps aux | grep -Ei "postgres" | grep -v grep | head -n 20 || true
echo

echo "===== LISTEN PORTS ====="
ss -ltnp 2>/dev/null | grep -Ei "8069|8071|5432|odoo|postgres" || true
netstat -ltnp 2>/dev/null | grep -Ei "8069|8071|5432|odoo|postgres" || true
echo

echo "===== ODOO CONF CANDIDATES ====="
find /etc /opt /home /srv -maxdepth 3 -type f \( -name "odoo.conf" -o -name "*.conf" \) 2>/dev/null | grep -Ei "odoo" | head -n 20 || true
echo

echo "===== TOP DIRS ====="
ls -la /opt 2>/dev/null || true
ls -la /srv 2>/dev/null || true
ls -la /home 2>/dev/null || true
' > "${RAW_FILE}"

HOSTNAME_LINE="$(grep -A1 '===== HOSTNAME =====' "${RAW_FILE}" | tail -n 1 | tr -d '\r' | xargs || true)"
ODOO_PROC_COUNT="$(grep -Ei 'odoo|odoo-bin' "${RAW_FILE}" | grep -v '===== ODOO PROCESS =====' | grep -v grep | wc -l | tr -d ' ')"
PG_PROC_COUNT="$(grep -Ei 'postgres' "${RAW_FILE}" | grep -v '===== POSTGRES PROCESS =====' | grep -v grep | wc -l | tr -d ' ')"
HAS_8069=false
grep -q '8069' "${RAW_FILE}" && HAS_8069=true || true
HAS_5432=false
grep -q '5432' "${RAW_FILE}" && HAS_5432=true || true

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg hostname "${HOSTNAME_LINE}" \
  --argjson odoo_proc_count "${ODOO_PROC_COUNT}" \
  --argjson pg_proc_count "${PG_PROC_COUNT}" \
  --argjson has_8069 "${HAS_8069}" \
  --argjson has_5432 "${HAS_5432}" \
  '{
    created_at: $created_at,
    remote_probe: {
      raw_file: $raw_file,
      hostname: $hostname,
      odoo_proc_count: $odoo_proc_count,
      postgres_proc_count: $pg_proc_count,
      has_8069: $has_8069,
      has_5432: $has_5432
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 81 — ODOO Remote Probe

## Probe
- raw_file: ${RAW_FILE}
- hostname: ${HOSTNAME_LINE}
- odoo_proc_count: ${ODOO_PROC_COUNT}
- postgres_proc_count: ${PG_PROC_COUNT}
- has_8069: ${HAS_8069}
- has_5432: ${HAS_5432}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] odoo remote probe gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
