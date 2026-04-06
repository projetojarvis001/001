#!/bin/bash
TELEGRAM_BOT_TOKEN="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
TELEGRAM_CHAT_ID="8206117553"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$1\"}" > /dev/null
}

# Watcher 1 — containers caídos
CAIDOS=$(docker ps -a --format "{{.Names}}:{{.Status}}" | grep -v "Up" | grep -v "^$")
if [ -n "$CAIDOS" ]; then
  notify "⚠️ JARVIS Watcher: containers caídos detectados:\n$CAIDOS"
fi

# Watcher 2 — disco cheio
USO_SSD=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$USO_SSD" -gt 80 ]; then
  notify "⚠️ JARVIS Watcher: SSD Mac1 em ${USO_SSD}% — atenção"
fi

# Watcher 3 — VISION offline
VISION=$(curl -s --max-time 5 http://192.168.8.124:5006/health 2>/dev/null | grep -c "ok")
if [ "$VISION" -eq 0 ]; then
  notify "❌ JARVIS Watcher: VISION Mac2 offline"
fi

# Watcher 4 — Genie offline
GENIE=$(curl -s --max-time 5 http://localhost:8000/health 2>/dev/null | grep -c "ok")
if [ "$GENIE" -eq 0 ]; then
  notify "❌ JARVIS Watcher: Genie Orchestrator offline"
fi

# Watcher 5 — memória Mac1
MEM=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
MEM_MB=$((MEM * 4096 / 1048576))
if [ "$MEM_MB" -lt 500 ]; then
  notify "⚠️ JARVIS Watcher: memória livre baixa — ${MEM_MB}MB disponíveis"
fi

echo "[$(date)] Watcher preditivo executado"
