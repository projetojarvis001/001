#!/usr/bin/env bash
set -e
MUTE_FILE="${TELEGRAM_MUTE_FILE:-runtime/TELEGRAM_MUTE}"

if [ "${TELEGRAM_ALERTS_ENABLED:-1}" = "0" ] || [ -f "${MUTE_FILE}" ]; then
  echo "[MUTED] Telegram bloqueado por chave operacional"
  exit 0
fi

exit 1
