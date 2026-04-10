#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated runtime/odoo

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="runtime/odoo/external_check_${TS}.txt"
OUT_JSON="logs/executive/phase85_odoo_external_check_${TS}.json"
OUT_MD="docs/generated/phase85_odoo_external_check_${TS}.md"

URL="${ODOO_URL:-}"

if [ -z "${URL}" ]; then
  echo "[ERRO] ODOO_URL nao definido"
  exit 1
fi

{
  echo "===== CURL ROOT ====="
  curl -I -L --max-time 20 "${URL}" 2>&1 || true
  echo
  echo "===== CURL LOGIN ====="
  curl -I -L --max-time 20 "${URL}/web/login" 2>&1 || true
} > "${RAW_FILE}"

HTTP_200=false
grep -Eq 'HTTP/[0-9.]+\s+200' "${RAW_FILE}" && HTTP_200=true || true

SERVER_HEADER=""
SERVER_HEADER="$(grep -i '^server:' "${RAW_FILE}" | head -n 1 | sed 's/\r//g' | xargs || true)"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg raw_file "${RAW_FILE}" \
  --arg server_header "${SERVER_HEADER}" \
  --argjson http_200 "${HTTP_200}" \
  '{
    created_at: $created_at,
    external_check: {
      raw_file: $raw_file,
      server_header: $server_header,
      http_200: $http_200
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 85 — ODOO External Check

## External
- raw_file: ${RAW_FILE}
- server_header: ${SERVER_HEADER}
- http_200: ${HTTP_200}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] external check gerado em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
