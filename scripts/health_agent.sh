#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
REPORT_FILE="/tmp/health_report.json"
TS=$(date '+%Y-%m-%d %H:%M:%S')

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

score=100
issues=""
warnings=""

check() {
  local layer=$1 name=$2 status=$3 impact=$4
  if [ "$status" = "FAIL" ]; then
    score=$((score - impact))
    issues="$issues\n❌ [$layer] $name"
  elif [ "$status" = "WARN" ]; then
    score=$((score - impact/2))
    warnings="$warnings\n⚠️ [$layer] $name"
  fi
}

# CAMADA 1 — FUNDAÇÃO
MEM_FREE=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
MEM_MB=$((MEM_FREE * 4096 / 1048576))
DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
[ "$MEM_MB" -lt 200 ] && check "HARDWARE" "RAM crítica ${MEM_MB}MB" "FAIL" 20
[ "$MEM_MB" -lt 500 ] && [ "$MEM_MB" -ge 200 ] && check "HARDWARE" "RAM baixa ${MEM_MB}MB" "WARN" 10
[ "$DISK" -gt 85 ] && check "HARDWARE" "Disco ${DISK}%" "FAIL" 15
TUNNEL=$(cat /tmp/current_tunnel_mac1.txt 2>/dev/null)
[ -z "$TUNNEL" ] && check "REDE" "Tunnel offline" "FAIL" 15

# CAMADA 2 — PLATAFORMA
CORE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000/health)
[ "$CORE" != "200" ] && check "PLATAFORMA" "jarvis-core offline" "FAIL" 25
VISION=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://192.168.8.124:5006/health)
[ "$VISION" != "200" ] && check "PLATAFORMA" "VISION offline" "FAIL" 20
OLLAMA=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://192.168.8.124:11434/api/tags)
[ "$OLLAMA" != "200" ] && check "PLATAFORMA" "Ollama offline" "FAIL" 15
PG=$(docker exec jarvis-postgres-1 pg_isready -U jarvis_admin 2>/dev/null | grep -c "accepting")
[ "$PG" -eq 0 ] && check "BD" "PostgreSQL offline" "FAIL" 20
REDIS=$(docker exec redis redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -c "PONG")
[ "$REDIS" -eq 0 ] && check "MENSAGERIA" "Redis offline" "WARN" 10

# CAMADA 3 — SISTEMA
BOOT_EXIT=$(launchctl list | grep "com.wagner.jarvis.boot" | awk '{print $2}')
[ "$BOOT_EXIT" = "127" ] && check "BOOT" "boot.sh erro 127 (cmd not found)" "FAIL" 10
ZEROCLAW_EXIT=$(launchctl list | grep "com.wagner.jarvis.zeroclaw" | awk '{print $2}')
[ "$ZEROCLAW_EXIT" = "1" ] && check "AGENTES" "ZeroClaw exit 1" "WARN" 5
DISP_DUP=$(ls ~/jarvis/core/src/dispatcher.ts ~/jarvis/core/src/services/dispatcher.ts 2>/dev/null | wc -l)
[ "$DISP_DUP" -ge 2 ] && check "CODIGO" "dispatcher.ts duplicado" "WARN" 5

# CAMADA 4 — OPERAÇÃO
TELEGRAM=$(curl -s "https://api.telegram.org/bot${BOT}/getMe" | grep -c '"ok":true')
[ "$TELEGRAM" -eq 0 ] && check "TELEGRAM" "Bot inacessível" "FAIL" 15
N8N=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5678/healthz 2>/dev/null)
[ "$N8N" != "200" ] && check "N8N" "N8n offline" "WARN" 5

# CAMADA 5 — INTELIGÊNCIA  
VECTORS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvis_db \
  -t -c "SELECT count(*) FROM knowledge_base;" 2>/dev/null | tr -d ' ')
VISION_VECTORS=$(curl -s http://192.168.8.124:5006/health 2>/dev/null | grep -o '"ok":true' | wc -l)
[ "$VISION_VECTORS" -eq 0 ] && check "MEMORIA" "VISION semântica offline" "FAIL" 15

# SCORE FINAL
[ $score -lt 0 ] && score=0
if [ $score -ge 90 ]; then STATUS="🟢 SAUDÁVEL"
elif [ $score -ge 70 ]; then STATUS="🟡 ATENÇÃO"
elif [ $score -ge 50 ]; then STATUS="🟠 DEGRADADO"
else STATUS="🔴 CRÍTICO"; fi

# GERA JSON para o dashboard
cat > $REPORT_FILE << JSONEOF
{
  "ts": "$TS",
  "score": $score,
  "status": "$STATUS",
  "mem_mb": $MEM_MB,
  "disk_pct": $DISK,
  "tunnel": "$(cat /tmp/current_tunnel_mac1.txt 2>/dev/null | head -1)",
  "core": "$CORE",
  "vision": "$VISION",
  "postgres": "$PG",
  "redis": "$REDIS",
  "telegram": "$TELEGRAM",
  "n8n": "$N8N",
  "issues": "$(echo -e "$issues" | tr '\n' '|')",
  "warnings": "$(echo -e "$warnings" | tr '\n' '|')"
}
JSONEOF

# Notifica só se degradado
if [ $score -lt 90 ]; then
  MSG="🏥 *Health Report JARVIS*
$(date '+%d/%m/%Y %H:%M')
Score: $score/100 — $STATUS

$(echo -e "$issues")
$(echo -e "$warnings")"
  notify "$MSG"
fi

echo "[$(date)] Health score: $score/100 — $STATUS"
