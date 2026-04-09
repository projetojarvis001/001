#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
OUT_DIR="logs/alerts"
OUT_FILE="${OUT_DIR}/stack_alert_$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${OUT_DIR}"

RESP=$(curl -s http://127.0.0.1:3000/stack/health || true)

if [ -z "$RESP" ]; then
  MSG="[ALERTA][JARVIS] stack/health sem resposta em ${STAMP}"
  echo "$MSG" | tee -a "$OUT_FILE"
  ./scripts/send_telegram_alert.sh "$MSG" || true
  exit 1
fi

OK=$(printf "%s" "$RESP" | jq -r '.ok // false')

if [ "$OK" != "true" ]; then
  MSG="[ALERTA][JARVIS] stack com falha em ${STAMP}"
  echo "$MSG" | tee -a "$OUT_FILE"
  echo "$RESP" | tee -a "$OUT_FILE"
  ./scripts/send_telegram_alert.sh "$MSG"$'\n'"$RESP" || true
  exit 1
fi

echo "[OK] stack saudavel"
