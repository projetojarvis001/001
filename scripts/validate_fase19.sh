#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 19 ====="

echo
echo "===== BRIEFING EXECUTIVO ====="
./scripts/send_morning_exec_briefing.sh >/tmp/briefing_f19.out
cat /tmp/briefing_f19.out

grep -q "Status atual:" /tmp/briefing_f19.out
grep -q "SLO do dia:" /tmp/briefing_f19.out
grep -q "Disponibilidade média 7d:" /tmp/briefing_f19.out
grep -q "Status executivo:" /tmp/briefing_f19.out
echo "[OK] briefing executivo consistente"

echo
echo "===== ROTINA DIARIA ====="
grep -q "send_morning_exec_briefing.sh" scripts/run_daily_stack_routine.sh
echo "[OK] rotina diaria integrada ao briefing"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase18.sh

echo
echo "[OK] fase 19 validada"
