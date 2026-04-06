#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\"}" > /dev/null
}

while true; do
  /opt/homebrew/bin/cloudflared tunnel --url http://localhost:3000 > /tmp/cf_mac1_out.log 2>&1 &
  CF_PID=$!
  sleep 10
  URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf_mac1_out.log | head -1)
  if [ -n "$URL" ]; then
    echo "$URL" > /tmp/current_tunnel_mac1.txt
    notify "🌐 JARVIS Mac1 online: $URL"
    wait $CF_PID
    notify "⚠️ Tunnel caiu — reiniciando..."
    sleep 5
  else
    kill $CF_PID 2>/dev/null
    sleep 30
  fi
done
