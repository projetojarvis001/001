#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"
ALERTAS=""

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

DATE_7=$(date -v+7d '+%Y-%m-%d' 2>/dev/null || date -d '+7 days' '+%Y-%m-%d')
DATE_30=$(date -v+30d '+%Y-%m-%d' 2>/dev/null || date -d '+30 days' '+%Y-%m-%d')

# Contratos expirando — banco jarvis_db (não jarvin que não existe)
CONTRATOS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvis_db \
  -t -c "SELECT client_name || ' — ' || expires_at::date FROM contracts 
         WHERE expires_at <= '$DATE_30' AND status='active' LIMIT 5;" \
  2>/dev/null | grep -v "^$" | head -5)
[ -n "$CONTRATOS" ] && ALERTAS="$ALERTAS\n⚠️ *Contratos expirando:*\n$CONTRATOS"

# Tarefas vencendo em 7 dias
TASKS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvis_db \
  -t -c "SELECT task_title || ' — ' || due_date::date FROM tasks 
         WHERE due_date <= '$DATE_7' AND status='pending' LIMIT 5;" \
  2>/dev/null | grep -v "^$" | head -5)
[ -n "$TASKS" ] && ALERTAS="$ALERTAS\n📋 *Tarefas vencendo:*\n$TASKS"

# Leads sem contato há 7+ dias
LEADS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvis_db \
  -t -c "SELECT client_name || ' — último contato: ' || last_contact::date FROM leads 
         WHERE last_contact <= NOW() - INTERVAL '7 days' AND status='active' LIMIT 5;" \
  2>/dev/null | grep -v "^$" | head -5)
[ -n "$LEADS" ] && ALERTAS="$ALERTAS\n🧊 *Leads frios:*\n$LEADS"

# SÓ envia se houver algo
if [ -n "$ALERTAS" ]; then
  notify "🔮 *Leitor do Futuro — $(date '+%d/%m %H:%M')*$(echo -e "$ALERTAS")"
fi

echo "[$(date)] Leitor do Futuro: $([ -n "$ALERTAS" ] && echo "alertas enviados" || echo "nenhuma pendencia")"
