#!/bin/bash
# Monitor Proativo JARVIS — detecta anomalias sem ser chamado
source /Users/jarvis001/jarvis/.env 2>/dev/null

BOT="$TELEGRAM_BOT_TOKEN"
CHAT="$TELEGRAM_CHAT_ID"
STATE_FILE="/tmp/jarvis_monitor_state.json"
ALERTAS=""

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

# Carrega estado anterior para evitar spam
prev_state() {
  python3 -c "
import json,os
f='$STATE_FILE'
if os.path.exists(f):
    d=json.load(open(f))
    print(d.get('$1',''))
else:
    print('')
" 2>/dev/null
}

save_state() {
  python3 -c "
import json,os
f='$STATE_FILE'
d=json.load(open(f)) if os.path.exists(f) else {}
d['$1']='$2'
json.dump(d,open(f,'w'))
" 2>/dev/null
}

# ── CHECK 1: Serviços críticos ────────────────────────────
for svc_name in "jarvis-core:http://localhost:3000/health" \
                "VISION:http://192.168.8.124:5006/health" \
                "Odoo:https://177.104.176.69/web/health" \
                "Agent:http://localhost:7777"; do
  NAME="${svc_name%%:*}"
  URL="${svc_name#*:}"
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$URL" 2>/dev/null)
  PREV=$(prev_state "svc_${NAME}")
  
  if [ "$HTTP" != "200" ] && [ "$PREV" != "DOWN" ]; then
    ALERTAS="$ALERTAS\n❌ *${NAME} caiu* (HTTP $HTTP)"
    save_state "svc_${NAME}" "DOWN"
  elif [ "$HTTP" = "200" ] && [ "$PREV" = "DOWN" ]; then
    notify "✅ *Monitor:* ${NAME} recuperado automaticamente"
    save_state "svc_${NAME}" "UP"
  elif [ "$HTTP" = "200" ]; then
    save_state "svc_${NAME}" "UP"
  fi
done

# ── CHECK 2: Containers críticos parados ─────────────────
CAIDOS=$(docker ps -a --format "{{.Names}}:{{.Status}}" 2>/dev/null | \
  grep -v "Up\|healthy" | \
  grep "jarvis-core\|postgres\|redis\|n8n\|prometheus" | \
  grep -v "^$")
if [ -n "$CAIDOS" ]; then
  ALERTAS="$ALERTAS\n⚠️ *Containers parados:*\n\`$CAIDOS\`"
fi

# ── CHECK 3: RAM disponível < 1GB ─────────────────────────
MEM_AVAIL=$(python3 -c "
import subprocess
r=subprocess.run(['vm_stat'],capture_output=True,text=True)
stats={}
for l in r.stdout.split('\n')[1:]:
    if ':' in l:
        k,v=l.split(':')
        try: stats[k.strip()]=int(v.strip().rstrip('.'))
        except: pass
avail=(stats.get('Pages free',0)+stats.get('Pages inactive',0)+stats.get('Pages speculative',0))*16384//1048576
print(avail)
" 2>/dev/null || echo "9999")
if [ "${MEM_AVAIL:-9999}" -lt 1000 ]; then
  ALERTAS="$ALERTAS\n⚠️ *RAM crítica:* ${MEM_AVAIL}MB disponível"
fi

# ── CHECK 4: Disco > 85% ──────────────────────────────────
DISCO=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "${DISCO:-0}" -gt 85 ]; then
  ALERTAS="$ALERTAS\n💿 *Disco crítico:* ${DISCO}% usado"
fi

# ── CHECK 5: Odoo sem resposta (túnel TADASH) ─────────────
TUNEL=$(curl -fsS http://localhost:19100/metrics 2>/dev/null | head -1)
if [ -z "$TUNEL" ]; then
  PREV=$(prev_state "tunel_tadash")
  if [ "$PREV" != "DOWN" ]; then
    ALERTAS="$ALERTAS\n🔌 *Túnel TADASH caiu* — node_exporter inacessível"
    save_state "tunel_tadash" "DOWN"
  fi
else
  save_state "tunel_tadash" "UP"
fi

# ── CHECK 6: Agent LangGraph offline ──────────────────────
AGENT=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:7777 2>/dev/null)
if [ "$AGENT" != "200" ]; then
  PREV=$(prev_state "agent_server")
  if [ "$PREV" != "DOWN" ]; then
    # Tenta reiniciar
    export PYTHONPATH="/Users/jarvis001/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"
    pkill -f agent_server.py 2>/dev/null
    sleep 1
    nohup python3 /Users/jarvis001/jarvis/agents/agent_server.py \
      >> /tmp/agent_server.log 2>&1 &
    sleep 5
    AGENT2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:7777 2>/dev/null)
    if [ "$AGENT2" = "200" ]; then
      notify "🔧 *Monitor:* Agent LangGraph auto-recuperado"
      save_state "agent_server" "UP"
    else
      ALERTAS="$ALERTAS\n🧠 *Agent LangGraph offline* após tentativa de fix"
      save_state "agent_server" "DOWN"
    fi
  fi
else
  save_state "agent_server" "UP"
fi

# ── ENVIA SE HOUVER ALERTAS ───────────────────────────────
if [ -n "$ALERTAS" ]; then
  MSG="🚨 *Monitor Proativo JARVIS*
$(date '+%d/%m %H:%M')
$(echo -e "$ALERTAS")"
  notify "$MSG"
  echo "[$(date)] ALERTAS ENVIADOS: $ALERTAS"
else
  echo "[$(date)] Monitor OK — nenhuma anomalia"
fi
