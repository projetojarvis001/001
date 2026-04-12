#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
LOG="/tmp/updater_agent.log"
UPDATES=""

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\"}" > /dev/null
}

echo "[$(date)] Updater iniciando..." >> $LOG

# Git — commits novos no remoto
cd ~/jarvis
git fetch origin --quiet 2>/dev/null
BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "0")
[ "$BEHIND" -gt 0 ] && UPDATES="$UPDATES\n📦 Git: $BEHIND commits novos no remoto"

# Disco — limpeza se > 80%
DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK" -gt 80 ]; then
  PRUNED=$(docker system prune -f 2>/dev/null | tail -1)
  UPDATES="$UPDATES\n🧹 Disco em ${DISK}% — limpeza Docker executada"
fi

# NPM outdated crítico
OUTDATED=$(cd ~/jarvis/core && npm outdated 2>/dev/null | grep -c "." || echo "0")
[ "$OUTDATED" -gt 0 ] 2>/dev/null && UPDATES="$UPDATES\n📦 NPM: $OUTDATED pacotes desatualizados"

# SÓ notifica se houver algo
if [ -n "$UPDATES" ]; then
  notify "🔄 Updater Agent $(date '+%d/%m %H:%M')$(echo -e "$UPDATES")"
fi

echo "[$(date)] Updater concluído $([ -n "$UPDATES" ] && echo "— atualizações enviadas" || echo "— sem novidades")" >> $LOG
