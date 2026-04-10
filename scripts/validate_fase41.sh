#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 41 ====="

STATE_FILE="logs/state/change_freeze.state"

echo
echo "===== TESTE FREEZE POR RISK BLOCK ====="
TMP_RISK="logs/readiness/operational_risk_override_test.json"

cat > "${TMP_RISK}" <<'JSON'
{
  "decision": {
    "risk_level": "CRITICAL",
    "go_live_status": "BLOQUEAR",
    "change_policy": "FREEZE",
    "operator_note": "Teste de freeze automatico"
  }
}
JSON

cp "${TMP_RISK}" "logs/readiness/operational_risk_99999999-999999.json"

./scripts/freeze_on_critical_event.sh

LATEST_FREEZE="$(ls -1t logs/readiness/freeze_event_*.json 2>/dev/null | head -n 1 || true)"
test -f "${STATE_FILE}"
jq -e '.result.freeze_active == true' "${LATEST_FREEZE}" >/dev/null
echo "[OK] freeze ativado por risk gate"

rm -f "logs/readiness/operational_risk_99999999-999999.json" "${TMP_RISK}"

echo
echo "===== TESTE UNFREEZE ====="
ACTOR="jarvis001" REASON="teste_fase41" ./scripts/unfreeze_controlled.sh
test ! -f "${STATE_FILE}"
echo "[OK] unfreeze controlado validado"

echo
echo "===== REPORT ====="
./scripts/freeze_event_report.sh "${LATEST_FREEZE}"

echo
echo "===== SANIDADE ====="
grep -q 'freeze_on_critical_event.sh' scripts/run_daily_stack_routine.sh
echo "[OK] rotina diaria contem freeze automatico"

echo
echo "[OK] fase 41 validada"
