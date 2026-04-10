#!/bin/bash
if ./scripts/telegram_guard.sh; then
  exit 0
fi

BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
LOG="/tmp/code_agent.log"
VISION="http://192.168.8.124:5006"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\",\"parse_mode\":\"Markdown\"}" > /dev/null
}

echo "[$(date)] Code Agent iniciando..." >> $LOG

ERRORS=$(docker logs jarvis-jarvis-core-1 --since 2h 2>&1 | grep -iE "error|fatal|exception|cannot|undefined|null" | grep -v "^#" | tail -10)

if [ -n "$ERRORS" ]; then
  echo "[$(date)] Erros detectados: $ERRORS" >> $LOG
  
  FIX=$(curl -s -X POST "$VISION/search-and-generate" \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"fix nodejs typescript error\",
      \"prompt\": \"Você é um engenheiro sênior Node.js/TypeScript. Analise estes erros e gere o patch de correção em bash (sed, substituição de arquivo). Responda APENAS com comandos bash executáveis, sem explicação:\n\n$ERRORS\n\nArquivos em: ~/jarvis/core/src/\",
      \"model\": \"qwen2.5:14b\",
      \"limit\": 3
    }" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)

  if [ -n "$FIX" ]; then
    echo "$FIX" > /tmp/proposed_fix.sh
    notify "🔧 *Code Agent — Fix proposto*

\`\`\`
$(echo "$FIX" | head -10)
\`\`\`

Aplicar? Responda /aplicar_fix ou /ignorar_fix"
    echo "[$(date)] Fix proposto salvo em /tmp/proposed_fix.sh" >> $LOG
  fi
else
  echo "[$(date)] Nenhum erro crítico detectado" >> $LOG
fi

TODOS=$(docker logs jarvis-jarvis-core-1 --since 2h 2>&1 | grep -i "TODO\|FIXME\|HACK\|XXX" | tail -5)
if [ -n "$TODOS" ]; then
  notify "📝 *Code Agent — TODOs detectados*\n\`\`\`\n$TODOS\n\`\`\`"
fi
