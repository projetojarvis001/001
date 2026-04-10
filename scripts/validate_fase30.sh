#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 30 ====="

echo
echo "===== READINESS GATE ====="
./scripts/readiness_gate.sh

LATEST=$(ls -1t logs/readiness/readiness_*.json | head -n 1)
test -f "${LATEST}"
echo "[OK] readiness selecionado: ${LATEST}"

echo
echo "===== CHECK JSON ====="
jq -e '.readiness != null' "${LATEST}" >/dev/null
jq -e '.executive_recommendation != null' "${LATEST}" >/dev/null
jq -e '.score != null' "${LATEST}" >/dev/null
jq -e '.checks != null' "${LATEST}" >/dev/null
jq -e '.artifacts != null' "${LATEST}" >/dev/null
echo "[OK] json readiness consistente"

echo
echo "===== REPORT ====="
./scripts/readiness_report.sh "${LATEST}"

echo
echo "===== REGRA FINAL ====="
jq -e '.score >= 90' "${LATEST}" >/dev/null
jq -e '.readiness == "READY"' "${LATEST}" >/dev/null
echo "[OK] stack aprovada no gate final"

echo
echo "===== HEALTH BASE ====="
./scripts/validate_fase29.sh

echo
echo "[OK] fase 30 validada"
