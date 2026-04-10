#!/usr/bin/env bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

set -e
./scripts/send_telegram_alert.sh "[TESTE FALHA] Simulacao manual de incidente da stack vision"
