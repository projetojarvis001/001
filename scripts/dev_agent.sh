#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"
LOG="/tmp/dev_agent.log"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\"}" > /dev/null
}

echo "[$(date)] Dev Agent iniciando..." >> $LOG

ERRORS=$(docker logs jarvis-core-1 --since 1h 2>&1 | grep -i "error\|ERROR\|fatal" | tail -5)

if [ -n "$ERRORS" ]; then
  notify "🔧 *Dev Agent — Erros detectados*

\`\`\`
$ERRORS
\`\`\`

Analisando e propondo fix..."

  FIX=$(~/zeroclaw/target/release/zeroclaw agent -m \
    "Analise esses erros do JARVIS e proponha solução em 3 linhas: $ERRORS" 2>/dev/null)

  notify "💡 *Fix sugerido:*
$FIX"
  echo "[$(date)] Erros detectados e analisados" >> $LOG
else
  echo "[$(date)] Nenhum erro crítico" >> $LOG
fi

DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK" -gt 85 ]; then
  docker system prune -f >> $LOG 2>&1
  notify "🧹 Dev Agent: limpeza Docker executada — disco estava em ${DISK}%"
fi

CONTAINERS_DOWN=$(docker ps -a --format "{{.Names}}:{{.Status}}" | grep -v "Up\|healthy" | grep -v "^$")
if [ -n "$CONTAINERS_DOWN" ]; then
  notify "🔄 Dev Agent: reiniciando containers caídos..."
  docker compose -f ~/jarvis/docker-compose.yml up -d >> $LOG 2>&1
  notify "✅ Dev Agent: containers reiniciados"
fi
