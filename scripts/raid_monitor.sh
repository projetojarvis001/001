#!/bin/bash
JARVIS_PORT_CHECK=$(curl -fsS --max-time 5 http://localhost:7777 2>/dev/null)
BOT=$(grep TELEGRAM_BOT_TOKEN /Users/jarvis001/jarvis/.env | cut -d= -f2)
CHAT=$(grep TELEGRAM_CHAT_ID /Users/jarvis001/jarvis/.env | cut -d= -f2)

if [ -z "$JARVIS_PORT_CHECK" ]; then
    echo "[$(date)] JARVIS agentes offline — tentando recuperar"
    
    # Tenta reiniciar LaunchAgents
    for label in com.jarvis.agent.server com.jarvis.auto.server com.jarvis.intel.server; do
        launchctl kickstart -k gui/$(id -u)/$label 2>/dev/null || true
    done
    
    sleep 10
    
    # Verifica novamente
    if curl -fsS --max-time 5 http://localhost:7777 > /dev/null 2>&1; then
        curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" -d "chat_id=${CHAT}" -d "text=JARVIS auto-recuperado pelo RAID monitor" > /dev/null 2>&1
    else
        curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" -d "chat_id=${CHAT}" -d "text=ATENCAO: JARVIS agentes offline. Verificar manualmente." > /dev/null 2>&1
    fi
fi
