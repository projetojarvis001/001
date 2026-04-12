#!/bin/bash
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

if ./scripts/telegram_guard.sh; then
  exit 0
fi

if [ -f /tmp/jarvis_pausado ]; then
  echo "[$(date)] Guardian em pausa — skip notificações"
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"
LOG="/tmp/guardian.log"
ERROS=0

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

check_and_fix() {
  local NAME=$1 URL=$2 FIX_CMD=$3
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null)
  if [ "$HTTP" != "200" ]; then
    echo "[$(date)] FALHA $NAME ($HTTP) — tentando fix..." >> $LOG
    cd /Users/jarvis001/jarvis && eval "$FIX_CMD" >> $LOG 2>&1
    sleep 5
    HTTP2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null)
    if [ "$HTTP2" = "200" ]; then
      notify "✅ *Guardian auto-fix:* $NAME recuperado"
      echo "[$(date)] $NAME recuperado" >> $LOG
    else
      notify "❌ *Guardian ALERTA:* $NAME falhou após fix ($HTTP2)"
      ERROS=$((ERROS+1))
    fi
  fi
}

check_and_fix "jarvis-core" \
  "http://localhost:3000/health" \
  "docker compose up -d jarvis-core"

check_and_fix "VISION-semantic" \
  "http://192.168.8.124:5006/health" \
  "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 vision@192.168.8.124 'launchctl kickstart -k gui/\$(id -u)/com.jarvis.vision.semantic' 2>/dev/null || true"

check_and_fix "postgres" \
  "http://localhost:3000/health" \
  "docker compose up -d postgres"

TUNNEL_URL=$(cat /tmp/current_tunnel_mac1.txt 2>/dev/null)
if [ -z "$TUNNEL_URL" ]; then
  notify "⚠️ *Guardian:* Tunnel offline — reiniciando"
  launchctl kickstart -k gui/$(id -u)/com.wagner.jarvis.tunnel >> $LOG 2>&1
fi

CONTAINERS_DOWN=$(docker ps -a --format "{{.Names}}:{{.Status}}" | grep -v "Up\|healthy" | grep "jarvis\|redis" | grep -v "^$")
if [ -n "$CONTAINERS_DOWN" ]; then
  cd /Users/jarvis001/jarvis && docker compose up -d >> $LOG 2>&1
  notify "🔄 *Guardian:* Containers reiniciados\n\`$CONTAINERS_DOWN\`"
fi

DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
[ "${DISK:-0}" -gt 85 ] && docker system prune -f >> $LOG 2>&1 && notify "🧹 *Guardian:* Limpeza disco executada (${DISK}%)"

[ $ERROS -eq 0 ] && echo "[$(date)] Guardian OK — tudo saudável" >> $LOG
