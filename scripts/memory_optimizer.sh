#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
LOG="/tmp/memory_optimizer.log"
NODE="Mac1-JARVIS"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

MEM_FREE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
MEM_FREE_MB=$((MEM_FREE * 4096 / 1048576))

KILLERS=("Safari" "Spotify" "Slack" "Discord" "zoom.us" "Microsoft Teams" "Finder" "Photos")

if [ "$MEM_FREE_MB" -lt 400 ]; then
  LIBERADO=0
  for app in "${KILLERS[@]}"; do
    if pgrep -f "$app" > /dev/null 2>&1; then
      osascript -e "quit app \"$app\"" 2>/dev/null || killall "$app" 2>/dev/null || true
      LIBERADO=$((LIBERADO + 1))
    fi
  done
  killall WallpaperAerialsExtension 2>/dev/null || true
  sudo purge 2>/dev/null || true
  killall mediaanalysisd 2>/dev/null || true
  sleep 3
  MEM_AFTER=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
  MEM_AFTER_MB=$((MEM_AFTER * 4096 / 1048576))
  notify "🔧 *Memory Optimizer $NODE*
Livre antes: ${MEM_FREE_MB}MB
Livre depois: ${MEM_AFTER_MB}MB
Apps fechados: $LIBERADO"
fi

echo "[$(date)] $NODE — livre: ${MEM_FREE_MB}MB" >> $LOG
