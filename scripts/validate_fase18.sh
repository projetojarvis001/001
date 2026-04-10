#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 18 ====="

echo
echo "===== CLASSIFICADOR ====="
./scripts/classify_stack_alert.sh | jq .
./scripts/classify_stack_alert.sh > /tmp/classify_f18.json
jq -e '.severity != null' /tmp/classify_f18.json >/dev/null
jq -e '.alert_key != null' /tmp/classify_f18.json >/dev/null
jq -e '.title != null' /tmp/classify_f18.json >/dev/null
echo "[OK] classificador consistente"

echo
echo "===== ALERT STATE ====="
test -f logs/state/alert_state.json
cat logs/state/alert_state.json | jq .
jq -e '.last_alert_key != null' logs/state/alert_state.json >/dev/null
jq -e '.repeat_count != null' logs/state/alert_state.json >/dev/null
echo "[OK] estado de alerta consistente"

echo
echo "===== CHECK STACK ALERT ====="
./scripts/check_stack_alert.sh || true
echo "[OK] check_stack_alert executado"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase17.sh

echo
echo "[OK] fase 18 validada"
