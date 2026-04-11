#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".secrets/odoo_watchdog.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERRO] arquivo ${ENV_FILE} nao encontrado"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

echo "[OK] ambiente ODOO carregado"
printenv | grep '^ODOO_' | sed \
  -e 's/^ODOO_SSH_PASS=.*/ODOO_SSH_PASS=[REDACTED]/' \
  -e 's/^ODOO_APP_PASS=.*/ODOO_APP_PASS=[REDACTED]/' \
  -e 's/^ODOO_ALERT_WEBHOOK=.*/ODOO_ALERT_WEBHOOK=[REDACTED]/'
