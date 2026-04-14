#!/bin/bash
cd /Users/jarvis001/jarvis
export PYTHONPATH="/Users/jarvis001/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"
BOT=$(grep TELEGRAM_BOT_TOKEN .env | cut -d= -f2)
CHAT=$(grep TELEGRAM_CHAT_ID .env | cut -d= -f2)

notify() {
    curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
        -d "chat_id=${CHAT}" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null 2>&1
}

DATE=$(date "+%d/%m/%Y %H:%M")
MSG="JARVIS — Relatório Diário $DATE"

# Status agentes
ONLINE=0
OFFLINE=0
for port in 7777 7778 7779 7780 7781 7782 7783 7784 7785; do
    if curl -fsS --max-time 3 http://localhost:$port > /dev/null 2>&1; then
        ONLINE=$((ONLINE+1))
    else
        OFFLINE=$((OFFLINE+1))
    fi
done
MSG="$MSG\n\nAgentes: $ONLINE online"
[ $OFFLINE -gt 0 ] && MSG="$MSG | $OFFLINE OFFLINE"

# Containers Docker
CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
MSG="$MSG\nContainers: $CONTAINERS UP"

# VISION KB
VECTORS=$(curl -fsS http://192.168.8.124:5006/stats 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('vectors_total','?'))" 2>/dev/null)
MSG="$MSG\nKB: $VECTORS vetores"

# Selic
SELIC=$(curl -fsS "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados/ultimos/1?formato=json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0].get('valor','?')+'% a.d.')" 2>/dev/null)
MSG="$MSG\nSelic: $SELIC"

# MRR estimado do KB
MSG="$MSG\nMRR WPS: R\$156.000 (87 contratos)"

# Tailscale
TS=$(tailscale status 2>/dev/null | grep -c "online" || echo "?")
MSG="$MSG\nTailscale: $TS nos online"

MSG="$MSG\n\nBom dia, Wagner!"

notify "$MSG"
echo "Relatorio enviado: $(date)"
