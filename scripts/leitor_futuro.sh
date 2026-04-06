#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="8206117553"
DB_CONN="postgresql://jarvis_admin:W!@#wps@2026@localhost:5432/jarvin"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

DATE_7=$(date -v+7d '+%Y-%m-%d' 2>/dev/null || date -d '+7 days' '+%Y-%m-%d')
DATE_30=$(date -v+30d '+%Y-%m-%d' 2>/dev/null || date -d '+30 days' '+%Y-%m-%d')
TODAY=$(date '+%Y-%m-%d')

CONTRATOS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvin \
  -c "SELECT client_name, expires_at FROM contracts WHERE expires_at <= '$DATE_30' AND status='active' LIMIT 5;" \
  2>/dev/null | grep -v "^-\|^(\|client_name\|rows")

if [ -n "$CONTRATOS" ]; then
  notify "⚠️ *Leitor do Futuro — Contratos expirando*

$CONTRATOS

Ação recomendada: contatar clientes para renovação."
fi

TASKS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvin \
  -c "SELECT task_title, due_date FROM tasks WHERE due_date <= '$DATE_7' AND status='pending' LIMIT 5;" \
  2>/dev/null | grep -v "^-\|^(\|task_title\|rows")

if [ -n "$TASKS" ]; then
  notify "📋 *Leitor do Futuro — Tarefas vencendo em 7 dias*

$TASKS"
fi

LEADS_FRIOS=$(docker exec jarvis-postgres-1 psql -U jarvis_admin -d jarvin \
  -c "SELECT client_name, last_contact FROM leads WHERE last_contact <= NOW() - INTERVAL '7 days' AND status='active' LIMIT 5;" \
  2>/dev/null | grep -v "^-\|^(\|client_name\|rows")

if [ -n "$LEADS_FRIOS" ]; then
  notify "🧊 *Leitor do Futuro — Leads sem contato há 7+ dias*

$LEADS_FRIOS

Hora de um follow-up!"
fi

notify "🔮 *Leitor do Futuro — Verificação concluída*
$(date '+%d/%m/%Y %H:%M')
✅ Contratos, tarefas e leads verificados"

echo "[$(date)] Leitor do Futuro executado"
