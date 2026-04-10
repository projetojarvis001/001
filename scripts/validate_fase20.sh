#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 20 ====="

echo
echo "===== DIAGNOSTICO ====="
./scripts/diagnose_stack.sh | jq .

echo
echo "===== AUTO HEAL STATUS ====="
./scripts/show_auto_heal_status.sh >/tmp/autoheal_f20.out
cat /tmp/autoheal_f20.out

echo
echo "===== CHECK STATE ====="
test -f logs/state/auto_heal_state.json
jq -e '.last_action != null' logs/state/auto_heal_state.json >/dev/null
jq -e '.last_result != null' logs/state/auto_heal_state.json >/dev/null
jq -e '.last_diagnosis_kind != null' logs/state/auto_heal_state.json >/dev/null
jq -e '.last_command != null' logs/state/auto_heal_state.json >/dev/null
jq -e '.last_duration_seconds != null' logs/state/auto_heal_state.json >/dev/null
jq -e '.last_exit_code != null' logs/state/auto_heal_state.json >/dev/null
echo "[OK] estado rico do auto-heal consistente"

echo
echo "===== TESTE AUTOHEAL EM STACK SAUDAVEL ====="
./scripts/auto_heal_stack.sh
echo "[OK] auto-heal respeitou stack saudavel"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase19.sh

echo
echo "[OK] fase 20 validada"
