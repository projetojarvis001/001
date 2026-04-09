#!/usr/bin/env bash
set -e

STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="logs/alerts"
OUT_FILE="${OUT_DIR}/stack_alert_${STAMP}.log"

mkdir -p "${OUT_DIR}"

RESP=$(curl -s http://127.0.0.1:3000/stack/health || true)

if [ -z "$RESP" ]; then
  echo "[ALERTA] stack/health sem resposta" | tee -a "$OUT_FILE"
  exit 1
fi

OK=$(printf "%s" "$RESP" | jq -r '.ok // false')

if [ "$OK" != "true" ]; then
  echo "[ALERTA] stack com falha" | tee -a "$OUT_FILE"
  echo "$RESP" | tee -a "$OUT_FILE"
  exit 1
fi

echo "[OK] stack saudavel"
