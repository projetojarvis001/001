#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

TELEGRAM_BOT_TOKEN="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
TELEGRAM_CHAT_ID="8206117553"
ALERTAS=""

notify() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

# Watcher 1 — containers críticos caídos
CAIDOS=$(docker ps -a --format "{{.Names}}:{{.Status}}" \
  | grep -v "Up\|healthy" \
  | grep "jarvis-core\|postgres\|redis\|grafana\|n8n\|prometheus\|loki" \
  | grep -v "^$")
[ -n "$CAIDOS" ] && ALERTAS="$ALERTAS\n⚠️ Containers caídos:\n$CAIDOS"

# Watcher 2 — disco > 85%
USO_SSD=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
[ "${USO_SSD:-0}" -gt 85 ] && ALERTAS="$ALERTAS\n⚠️ SSD em ${USO_SSD}% — crítico"

# Watcher 3 — VISION offline
VISION=$(curl -s --max-time 5 http://192.168.8.124:5006/health 2>/dev/null | grep -c "ok")
[ "$VISION" -eq 0 ] && ALERTAS="$ALERTAS\n❌ VISION Semantic API offline"

# Watcher 4 — RAM disponível real no macOS M4 (page size = 16384 bytes)
MEM_MB=$(python3 -c "
import subprocess
r = subprocess.run(['vm_stat'], capture_output=True, text=True)
stats = {}
for l in r.stdout.split('\n')[1:]:
    if ':' in l:
        k,v = l.split(':')
        try: stats[k.strip()] = int(v.strip().rstrip('.'))
        except: pass
page = 16384
avail = (stats.get('Pages free',0) + stats.get('Pages inactive',0) + stats.get('Pages speculative',0)) * page // 1048576
print(avail)
" 2>/dev/null || echo "9999")
[ "${MEM_MB:-9999}" -lt 1000 ] && ALERTAS="$ALERTAS\n⚠️ RAM disponível: ${MEM_MB}MB (abaixo de 1GB)"

# SÓ notifica se houver alerta real
if [ -n "$ALERTAS" ]; then
  notify "🔍 *Watcher Preditivo — $(date '+%d/%m %H:%M')*$(echo -e "$ALERTAS")"
fi

echo "[$(date)] Watcher: $([ -n "$ALERTAS" ] && echo "ALERTA ENVIADO" || echo "tudo ok — RAM ${MEM_MB}MB livre")"
