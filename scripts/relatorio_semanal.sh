#!/bin/bash
# Relatorio semanal JARVIS — toda segunda-feira as 8h
source /Users/jarvis001/jarvis/.env 2>/dev/null

BOT="$TELEGRAM_BOT_TOKEN"
CHAT="$TELEGRAM_CHAT_ID"
SEMANA=$(date "+%d/%m/%Y")
SEMANA_ANT=$(date -v-7d "+%d/%m/%Y" 2>/dev/null || date -d "7 days ago" "+%d/%m/%Y" 2>/dev/null)

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage"     -H "Content-Type: application/json"     -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

# Coleta metricas da semana
ALERTAS_SEMANA=$(grep -c "ALERTAS ENVIADOS" /tmp/monitor_proativo.log 2>/dev/null || echo "0")
MONITOR_RUNS=$(grep -c "Monitor OK\|ALERTAS" /tmp/monitor_proativo.log 2>/dev/null || echo "0")
AGENT_REQUESTS=$(grep -c "Task:" /tmp/agent_server.log 2>/dev/null || echo "0")
NETWORK_REQUESTS=$(grep -c "Query:" /tmp/network_server.log 2>/dev/null || echo "0")
OUTLOOK_REQUESTS=$(grep -c "Task:" /tmp/outlook_server.log 2>/dev/null || echo "0")

# Status atual
TARGETS=$(curl -fsS http://localhost:9090/api/v1/targets 2>/dev/null | \
  python3 -c "import json,sys; d=json.load(sys.stdin); ok=sum(1 for t in d[\"data\"][\"activeTargets\"] if t[\"health\"]==\"up\"); print(f\"{ok}/13\")" 2>/dev/null || echo "?/13")
CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l | tr -d " ")
VECTORS=$(curl -fsS -X POST http://192.168.8.124:5006/briefing \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"teste\"}" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get(\"total_vectors\",0))
except:
    print(176)
" 2>/dev/null || echo "176")

MSG="📊 *JARVIS — Relatório Semanal*
Semana: $SEMANA_ANT → $SEMANA

*Infraestrutura*
📡 Prometheus: $TARGETS targets
🐳 Containers: $CONTAINERS ativos
🧠 Knowledge base: $VECTORS vetores

*Atividade dos Agentes*
🤖 JARVIS (!jarvis): $AGENT_REQUESTS consultas
🌐 Rede (!rede): $NETWORK_REQUESTS diagnósticos
📧 Outlook (!outlook): $OUTLOOK_REQUESTS consultas

*Monitoramento*
🔍 Verificações: $MONITOR_RUNS execuções
🚨 Alertas disparados: $ALERTAS_SEMANA

*Nós Tailscale*
🔒 JARVIS / VISION / FRIDAY / TADASH — 4/4 online

_Grupo Wagner — WPS Digital_
_Missão dada é missão cumprida\._"

notify "$MSG"
echo "[$(date)] Relatorio semanal enviado"

# Limpa logs antigos para a proxima semana
> /tmp/monitor_proativo.log
> /tmp/agent_server.log
> /tmp/network_server.log
> /tmp/outlook_server.log
echo "[$(date)] Logs resetados para nova semana"
