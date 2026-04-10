#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 34 ====="

echo
echo "===== PREP STRICT ====="
./scripts/readiness_gate_strict.sh >/tmp/f34_readiness_strict.out

echo
echo "===== OPERATIONAL RISK ====="
./scripts/operational_risk_gate.sh

LATEST_RISK=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_RISK}" ] || [ ! -f "${LATEST_RISK}" ]; then
  echo "[ERRO] sem operational risk"
  exit 1
fi

echo "[OK] risk selecionado: ${LATEST_RISK}"

echo
echo "===== CHECK JSON ====="
jq -e '.decision.risk_level != null' "${LATEST_RISK}" >/dev/null
jq -e '.decision.go_live_status != null' "${LATEST_RISK}" >/dev/null
jq -e '.decision.change_policy != null' "${LATEST_RISK}" >/dev/null
jq -e '.observability.executive_status != null' "${LATEST_RISK}" >/dev/null
echo "[OK] risk gate consistente"

echo
echo "===== REPORT ====="
./scripts/operational_risk_report.sh "${LATEST_RISK}"

echo
echo "===== DASHBOARD ====="
./scripts/build_executive_ops_dashboard.sh
jq -e '.governance.risk_level != null' logs/executive/executive_ops_dashboard.json >/dev/null
jq -e '.governance.change_policy != null' logs/executive/executive_ops_dashboard.json >/dev/null
jq -e '.artifacts.risk_file != null' logs/executive/executive_ops_dashboard.json >/dev/null
echo "[OK] dashboard incorporou governanca de risco"

echo
echo "===== TESTE CHANGE FREEZE ====="
TMP_RISK_STRICT="/tmp/f34_strict_override.json"
cp "${LATEST_RISK}" /tmp/f34_risk_before.json

LATEST_STRICT=$(ls -1t logs/readiness/readiness_strict_*.json 2>/dev/null | head -n 1 || true)
cp "${LATEST_STRICT}" "${TMP_RISK_STRICT}"

python3 - <<PY
import json
from pathlib import Path
p = Path("${TMP_RISK_STRICT}")
obj = json.loads(p.read_text())
obj["readiness"] = "READY"
obj["score"] = 100
p.write_text(json.dumps(obj, indent=2))
print("[OK] strict override preparado")
PY

cp "${TMP_RISK_STRICT}" "logs/readiness/readiness_strict_override_test.json"

TMP_HISTORY="/tmp/f34_history_override.json"
curl -fsS http://127.0.0.1:3000/stack/history/compact > "${TMP_HISTORY}"

EXEC_STATUS=$(jq -r '.summary.executive_status // ""' "${TMP_HISTORY}")
INCIDENTS=$(jq -r '.summary.total_incidents_7d // 0' "${TMP_HISTORY}")

echo "EXEC_STATUS=${EXEC_STATUS}"
echo "INCIDENTS=${INCIDENTS}"

./scripts/operational_risk_gate.sh >/tmp/f34_risk_run.out
LATEST_RISK2=$(ls -1t logs/readiness/operational_risk_*.json 2>/dev/null | head -n 1 || true)

jq -e '.decision.risk_level != null' "${LATEST_RISK2}" >/dev/null
echo "[OK] gate operacional respondeu"

rm -f logs/readiness/readiness_strict_override_test.json
rm -f "${TMP_RISK_STRICT}"

echo
echo "===== REGRA FINAL ====="
jq -e '.decision.go_live_status == "LIBERAR" or .decision.go_live_status == "OPERAR_COM_CAUTELA" or .decision.go_live_status == "LIBERAR_COM_RISCO" or .decision.go_live_status == "BLOQUEAR"' "${LATEST_RISK2}" >/dev/null
echo "[OK] gate retornou decisao valida"

echo
echo "[OK] fase 34 validada"
