#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== CONFIG CHECK ====="
./scripts/check_config_consistency.sh || true

echo
echo "===== SNAPSHOT ====="
./scripts/snapshot_stack_health.sh

echo
echo "===== HISTORICO ====="
./scripts/record_daily_stack_history.sh >/dev/null
echo "[OK] historico diario atualizado"

echo
echo "===== EXPORT CSV ====="
./scripts/export_stack_history_csv.sh >/dev/null
echo "[OK] csv diario atualizado"

echo
echo "===== ALERT CHECK ====="
./scripts/check_stack_alert.sh

echo
echo "===== OPS REPORT ====="
./scripts/ops_report_vision.sh

echo
echo "===== RESUMO DIARIO ====="
./scripts/send_daily_stack_summary.sh

echo
echo "===== BRIEFING EXECUTIVO ====="
./scripts/send_morning_exec_briefing.sh

echo
echo "===== ROTACAO DE LOGS ====="
./scripts/rotate_logs.sh

echo
echo "===== RELATORIO DE RETENCAO ====="
./scripts/logs_retention_report.sh

echo
echo "===== EXCEPTION CLEANUP ====="
./scripts/exception_approval_cleanup.sh

echo
echo "===== BACKUP OPERACIONAL ====="
./scripts/backup_operational_state.sh

echo
echo "===== BACKUP POSTGRES ====="
./scripts/backup_postgres.sh

echo
echo "===== BACKUP REDIS ====="
./scripts/backup_redis.sh

echo
echo "===== BACKUP ENV ====="
./scripts/backup_env_secure.sh

echo
echo "===== READINESS SAFE ====="
./scripts/readiness_gate_safe.sh

echo
echo "===== READINESS STRICT ====="
./scripts/readiness_gate_strict.sh

echo
echo "===== OPERATIONAL RISK ====="
./scripts/operational_risk_gate.sh

echo
echo "===== FREEZE EVENT ====="
./scripts/freeze_on_critical_event.sh

echo
echo "===== DAILY CHANGE SUMMARY ====="
./scripts/daily_change_summary.sh

echo
echo "===== OPERATIONAL SCORE ====="
./scripts/operational_score_daily.sh

echo
echo "===== DASHBOARD EXECUTIVO ====="
./scripts/build_executive_ops_dashboard.sh

echo
echo "[OK] rotina diaria concluida"
