#!/bin/bash
LOG="/tmp/tunnel_mac1.log"
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\"}" > /dev/null
}

while true; do
  /opt/homebrew/bin/cloudflared tunnel --url http://localhost:3010 > /tmp/cf_mac1_out.log 2>&1 &
  CF_PID=$!
  sleep 10
  URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf_mac1_out.log | head -1)
  if [ -n "$URL" ]; then
    echo "[$(date)] Tunnel ativo: $URL" >> $LOG
    echo "$URL" > /tmp/current_tunnel_mac1.txt
    notify "🌐 J.A.R.V.I.S. Mac1 Tunnel: $URL"
    wait $CF_PID
    notify "⚠️ Mac1 Tunnel caiu — reiniciando..."
    sleep 5
  else
    kill $CF_PID 2>/dev/null
    sleep 30
  fi
done
