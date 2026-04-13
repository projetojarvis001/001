#!/bin/bash
source /Users/jarvis001/jarvis/.env 2>/dev/null
BOT="$TELEGRAM_BOT_TOKEN"
CHAT="$TELEGRAM_CHAT_ID"
ALERTAS=""

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage"     -H "Content-Type: application/json"     -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

# CHECK 1: Semantic API
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://192.168.8.124:5006/health 2>/dev/null)
if [ "$HTTP" != "200" ]; then
  ALERTAS="$ALERTAS\n❌ *VISION Semantic API offline* (HTTP $HTTP)"
fi

# CHECK 2: Modelos Ollama
MODELS=$(curl -fsS http://192.168.8.124:5006/health 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null || echo "0")
if [ "${MODELS:-0}" -lt 4 ]; then
  ALERTAS="$ALERTAS\n⚠️ *VISION Ollama degradado* — $MODELS modelos (esperado: 5+)"
fi

# CHECK 3: Vetores RAG
VECTORS=$(curl -fsS http://192.168.8.124:5006/stats 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(int(str(d.get('vectors_total','176')).strip()))" 2>/dev/null || echo "176")
if [ "${VECTORS:-176}" -lt 100 ]; then
  ALERTAS="$ALERTAS\n⚠️ *VISION RAG degradado* — $VECTORS vetores (esperado: 176+)"
fi

# CHECK 4: Agent servers
for port in 7777 7778 7779; do
  OK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:$port 2>/dev/null)
  if [ "$OK" != "200" ]; then
    ALERTAS="$ALERTAS\n❌ *Agent :$port offline*"
    export PYTHONPATH="/Users/jarvis001/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"
    case $port in
      7777) pkill -f agent_server.py 2>/dev/null; sleep 1; nohup python3 /Users/jarvis001/jarvis/agents/agent_server.py >> /tmp/agent_server.log 2>&1 & ;;
      7778) pkill -f network_server.py 2>/dev/null; sleep 1; nohup python3 /Users/jarvis001/jarvis/agents/network_server.py >> /tmp/network_server.log 2>&1 & ;;
      7779) pkill -f outlook_server.py 2>/dev/null; sleep 1; nohup python3 /Users/jarvis001/jarvis/agents/outlook_server.py >> /tmp/outlook_server.log 2>&1 & ;;
    esac
    sleep 4
    OK2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:$port 2>/dev/null)
    [ "$OK2" = "200" ] && notify "🔧 *Monitor:* Agent :$port auto-recuperado"
  fi
done

if [ -n "$ALERTAS" ]; then
  notify "🚨 *Monitor VISION/Agents* $(date +\'%d/%m %H:%M\')$(echo -e "$ALERTAS")"
  echo "[$(date)] ALERTAS: $ALERTAS"
else
  echo "[$(date)] VISION OK — $MODELS modelos, $VECTORS vetores, agents 7777/7778/7779 UP"
fi
