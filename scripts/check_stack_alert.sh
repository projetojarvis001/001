#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
OUT_DIR="logs/alerts"
STATE_DIR="logs/state"
OUT_FILE="${OUT_DIR}/stack_alert_$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="${STATE_DIR}/stack_status.state"

mkdir -p "${OUT_DIR}" "${STATE_DIR}"

LAST_STATE="unknown"
[ -f "${STATE_FILE}" ] && LAST_STATE=$(cat "${STATE_FILE}" 2>/dev/null || echo "unknown")

RESP=$(curl -s http://127.0.0.1:3000/stack/health || true)

CURRENT_STATE="down"
DETAIL="sem resposta"

if [ -n "$RESP" ]; then
  OK=$(printf "%s" "$RESP" | jq -r '.ok // false')
  if [ "$OK" = "true" ]; then
    CURRENT_STATE="up"
    DETAIL="stack saudavel"
  else
    CURRENT_STATE="down"
    DETAIL="$RESP"
  fi
fi

if [ "$CURRENT_STATE" = "down" ] && [ "$LAST_STATE" != "down" ]; then
  MSG="[ALERTA][JARVIS] stack caiu em ${STAMP}"
  echo "$MSG" | tee -a "$OUT_FILE"
  echo "$DETAIL" | tee -a "$OUT_FILE"
  ./scripts/send_telegram_alert.sh "$MSG"$'\n'"$DETAIL" || true
fi

if [ "$CURRENT_STATE" = "up" ] && [ "$LAST_STATE" = "down" ]; then
  MSG="[RECUPERADO][JARVIS] stack normalizada em ${STAMP}"
  echo "$MSG" | tee -a "$OUT_FILE"
  ./scripts/send_telegram_alert.sh "$MSG" || true
fi

echo "$CURRENT_STATE" > "${STATE_FILE}"

if [ "$CURRENT_STATE" = "up" ]; then
  echo "[OK] stack saudavel"
  exit 0
fi

echo "[ALERTA] stack com falha"
exit 1
