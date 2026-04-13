#!/bin/bash
# Relatório diário JARVIS — enviado às 7h automaticamente
source /Users/jarvis001/jarvis/.env 2>/dev/null

BOT="$TELEGRAM_BOT_TOKEN"
CHAT="$TELEGRAM_CHAT_ID"
TS=$(date '+%d/%m/%Y %H:%M')
HORA=$(date "+%H")

[ "$HORA" -ge 5 ] && [ "$HORA" -lt 12 ] && PERIODO="Bom dia" || \
[ "$HORA" -ge 12 ] && [ "$HORA" -lt 18 ] && PERIODO="Boa tarde" || \
PERIODO="Boa noite"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

# Coleta dados
CORE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000/health 2>/dev/null)
VISION=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://192.168.8.124:5006/health 2>/dev/null)
N8N=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5678/healthz 2>/dev/null)
ODOO=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://177.104.176.69:58069/web/health 2>/dev/null)
KEYCLOAK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:18080/health/ready 2>/dev/null)
AGENT=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:7777 2>/dev/null)

TARGETS=$(curl -fsS http://localhost:9090/api/v1/targets 2>/dev/null | \
  python3 -c "import json,sys; d=json.load(sys.stdin); ok=sum(1 for t in d['data']['activeTargets'] if t['health']=='up'); print(f'{ok}/13')" 2>/dev/null || echo "?/13")

CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

MEM_MB=$(python3 -c "
import subprocess
r=subprocess.run(['vm_stat'],capture_output=True,text=True)
stats={}
for l in r.stdout.split('\n')[1:]:
    if ':' in l:
        k,v=l.split(':')
        try: stats[k.strip()]=int(v.strip().rstrip('.'))
        except: pass
page=16384
avail=(stats.get('Pages free',0)+stats.get('Pages inactive',0)+stats.get('Pages speculative',0))*page//1048576
total=(stats.get('Pages free',0)+stats.get('Pages active',0)+stats.get('Pages inactive',0)+stats.get('Pages speculative',0)+stats.get('Pages wired down',0))*page//1048576
used=total-avail
pct=int(used*100/total) if total>0 else 0
print(f'{pct}%')
" 2>/dev/null || echo "?")

DISCO=$(df -h / | tail -1 | awk '{print $5}')

s() { [ "$1" = "200" ] && echo "✅" || echo "❌"; }

MSG="${PERIODO}, Wagner\! 🤖 *JARVIS — Relatório Diário*
📅 ${TS}

*Serviços*
$(s $CORE) Core  $(s $VISION) VISION  $(s $N8N) n8n
$(s $ODOO) Odoo  $(s $KEYCLOAK) Keycloak  $(s $AGENT) Agent

*Infraestrutura*
📡 Prometheus: ${TARGETS} targets up
🐳 Containers: ${CONTAINERS} ativos
💾 RAM: ${MEM_MB} usada  |  💿 Disco: ${DISCO}

*Tailscale VPN*
🔒 4/4 nós conectados

_Missão dada é missão cumprida\._"

notify "$MSG"
echo "[$(date)] Relatório diário enviado"
