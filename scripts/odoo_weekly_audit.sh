#!/usr/bin/env bash
set -euo pipefail

echo "===== ODOO WEEKLY AUDIT ====="

echo
echo "===== FASE 93 / WATCHDOG ====="
./scripts/phase93_odoo_remote_watchdog_probe.sh

echo
echo "===== FASE 94 / RETENTION ====="
./scripts/phase94_odoo_watchdog_retention_probe.sh

echo
echo "===== FASE 95 / ALERTA ====="
./scripts/phase95_odoo_alert_delivery_probe.sh

echo
echo "===== FASE 97 / DRIFT ====="
./scripts/phase97_odoo_watchdog_drift_probe.sh

echo
echo "===== FASE 98 / RESTORE ====="
./scripts/phase98_odoo_watchdog_restore_probe.sh

echo
echo "===== FASE 99 / FALLBACK ====="
./scripts/phase99_odoo_alert_fallback_probe.sh

echo
echo "===== FASE 100 / FECHAMENTO ====="
./scripts/validate_fase100.sh

echo
echo "[OK] auditoria semanal do ODOO concluida"
