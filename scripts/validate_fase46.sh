#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

LEDGER_FILE="logs/ops/ops_event_ledger.jsonl"
PROMOTION_FILE="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
FREEZE_FILE="$(ls -1t logs/readiness/freeze_event_*.json 2>/dev/null | head -n 1 || true)"

echo "===== VALIDATE FASE 46 ====="

echo
echo "===== PREP SOURCES ====="
if [ -z "${PROMOTION_FILE}" ] || [ -z "${MANIFEST_FILE}" ] || [ -z "${FREEZE_FILE}" ]; then
  echo "[ERRO] fontes nao encontradas"
  exit 1
fi
mkdir -p "$(dirname "${LEDGER_FILE}")"
touch "${LEDGER_FILE}"
echo "[OK] fontes localizadas"

echo
echo "===== APPEND EVENTS ====="
./scripts/ops_event_append.sh promotion "${PROMOTION_FILE}"
./scripts/ops_event_append.sh manifest "${MANIFEST_FILE}"
./scripts/ops_event_append.sh freeze "${FREEZE_FILE}"

echo
echo "===== CHECK LEDGER ====="
tail -n 3 "${LEDGER_FILE}" | jq -s '.' >/dev/null
echo "[OK] ledger append-only valido"

echo
echo "===== CHECK EVENTS ====="
tail -n 3 "${LEDGER_FILE}" | jq -s -e 'length == 3' >/dev/null
tail -n 3 "${LEDGER_FILE}" | jq -s -e '.[0].event_type != null' >/dev/null
tail -n 3 "${LEDGER_FILE}" | jq -s -e '.[1].event_type != null' >/dev/null
tail -n 3 "${LEDGER_FILE}" | jq -s -e '.[2].event_type != null' >/dev/null
echo "[OK] eventos registrados"

echo
echo "===== REPORT ====="
./scripts/ops_event_report.sh

echo
echo "===== SANIDADE ====="
bash -n scripts/ops_event_append.sh
bash -n scripts/ops_event_report.sh
bash -n scripts/validate_fase46.sh
echo "[OK] sintaxe shell valida"

echo
echo "[OK] fase 46 validada"
