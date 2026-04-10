#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

echo "===== VALIDATE FASE 46 ====="

LEDGER_FILE="logs/ops/ops_event_ledger.jsonl"
mkdir -p logs/ops
touch "${LEDGER_FILE}"

BEFORE_LINES=$(wc -l < "${LEDGER_FILE}" | tr -d ' ')

echo
echo "===== PREP SOURCES ====="
PROMO_FILE="$(ls -1t logs/release/promotion_*.json 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="$(ls -1t logs/release/release_manifest_*.json 2>/dev/null | head -n 1 || true)"
FREEZE_FILE="$(ls -1t logs/readiness/freeze_event_*.json 2>/dev/null | head -n 1 || true)"

if [ -z "${PROMO_FILE}" ] || [ ! -f "${PROMO_FILE}" ]; then
  echo "[ERRO] sem promotion file"
  exit 1
fi

if [ -z "${MANIFEST_FILE}" ] || [ ! -f "${MANIFEST_FILE}" ]; then
  echo "[ERRO] sem manifest file"
  exit 1
fi

if [ -z "${FREEZE_FILE}" ] || [ ! -f "${FREEZE_FILE}" ]; then
  echo "[ERRO] sem freeze file"
  exit 1
fi

echo "[OK] fontes localizadas"

echo
echo "===== APPEND EVENTS ====="
./scripts/ops_event_append.sh promotion "${PROMO_FILE}"
./scripts/ops_event_append.sh manifest "${MANIFEST_FILE}"
./scripts/ops_event_append.sh freeze "${FREEZE_FILE}"

AFTER_LINES=$(wc -l < "${LEDGER_FILE}" | tr -d ' ')

echo
echo "===== CHECK LEDGER ====="
if [ "${AFTER_LINES}" -le "${BEFORE_LINES}" ]; then
  echo "[ERRO] ledger nao cresceu"
  exit 1
fi

tail -n 3 "${LEDGER_FILE}" | jq -s '.' >/dev/null
echo "[OK] ledger append-only valido"

echo
echo "===== CHECK EVENTS ====="
tail -n 3 "${LEDGER_FILE}" | jq -s -e '
  length == 3
  and .[0].event_type == "promotion"
  and .[1].event_type == "manifest"
  and .[2].event_type == "freeze"
' >/dev/null
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
