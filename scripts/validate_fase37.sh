#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 37 ====="

FREEZE_FILE="logs/readiness/change_freeze.flag"
mkdir -p logs/readiness
rm -f "${FREEZE_FILE}"

echo
echo "===== TESTE JANELA ABERTA FORCADA ====="
WINDOW_START="00:00" WINDOW_END="23:59" ./scripts/change_window_gate.sh
LATEST=$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)

jq -e '.decision.authorized == true' "${LATEST}" >/dev/null
jq -e '.decision.status == "OPEN"' "${LATEST}" >/dev/null
echo "[OK] janela aberta validada"

echo
echo "===== TESTE BLOQUEIO FORA DA JANELA ====="
WINDOW_START="00:00" WINDOW_END="00:01" ./scripts/change_window_gate.sh || true
LATEST=$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)

jq -e '.decision.authorized == false' "${LATEST}" >/dev/null
jq -e '.decision.status == "BLOCKED_WINDOW"' "${LATEST}" >/dev/null
echo "[OK] bloqueio fora da janela validado"

echo
echo "===== TESTE OVERRIDE ====="
WINDOW_START="00:00" WINDOW_END="00:01" ALLOW_OUTSIDE_WINDOW=1 ./scripts/change_window_gate.sh
LATEST=$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)

jq -e '.decision.authorized == true' "${LATEST}" >/dev/null
jq -e '.decision.status == "OVERRIDE"' "${LATEST}" >/dev/null
echo "[OK] override validado"

echo
echo "===== TESTE FREEZE ====="
touch "${FREEZE_FILE}"
WINDOW_START="00:00" WINDOW_END="23:59" ./scripts/change_window_gate.sh || true
LATEST=$(ls -1t logs/readiness/change_window_*.json 2>/dev/null | head -n 1 || true)

jq -e '.runtime.freeze_active == true' "${LATEST}" >/dev/null
jq -e '.decision.status == "BLOCKED_FREEZE" or .decision.status == "OVERRIDE"' "${LATEST}" >/dev/null
echo "[OK] freeze validado"

rm -f "${FREEZE_FILE}"

echo
echo "===== REPORT ====="
./scripts/change_window_report.sh "${LATEST}"

echo
echo "[OK] fase 37 validada"
