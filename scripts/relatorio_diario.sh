#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
TS=$(date '+%d/%m/%Y %H:%M')
source /Users/jarvis001/jarvis/.env 2>/dev/null
SCORE=$(python3 /Users/jarvis001/jarvis/scripts/health_agent.py 2>/dev/null | grep "Health score" | awk '{print $4}' | cut -d'/' -f1)
MEM=$(vm_stat | grep "Pages free" | awk '{printf "%.0f", $3*4096/1048576}')
IP=$(cat /tmp/network_report.json 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('public_ip','?'))" 2>/dev/null)
CF=$(cat /tmp/network_report.json 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('latency_cf_ms','?'))" 2>/dev/null)
CORE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000/health 2>/dev/null)
VISION=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://192.168.8.124:5006/health 2>/dev/null)
N8N=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5678/healthz 2>/dev/null)
CONTAINERS=$(docker ps --format "{{.Names}}" | wc -l | tr -d " ")
TUNNEL=$(cat /tmp/current_tunnel_mac1.txt 2>/dev/null | sed "s/https:\/\///" | cut -c1-30)
HORA=$(date "+%H")
if [ "$HORA" = "07" ]; then PERIODO="Bom dia"
elif [ "$HORA" = "13" ]; then PERIODO="Boa tarde"
else PERIODO="Boa noite"; fi
CORE_STATUS=$([ "$CORE" = "200" ] && echo "OK" || echo "FALHA")
VISION_STATUS=$([ "$VISION" = "200" ] && echo "OK" || echo "FALHA")
N8N_STATUS=$([ "$N8N" = "200" ] && echo "OK" || echo "FALHA")
MSG="$PERIODO, Wagner! JARVIS Relatorio $TS | Score: ${SCORE:-?}/100 | RAM: ${MEM}MB | Containers: $CONTAINERS | Core: $CORE_STATUS | Vision: $VISION_STATUS | N8n: $N8N_STATUS | IP: $IP | CF: ${CF}ms | Tunnel: $TUNNEL | Missao cumprida."
curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" -H "Content-Type: application/json" -d "{\"chat_id\":\"$CHAT\",\"text\":\"$MSG\"}" > /dev/null
echo "[$(date)] Relatorio enviado"
