#!/bin/bash
source /Users/jarvis001/jarvis/.env
source /Users/jarvis001/jarvin-universal/.env

DATE=$(date '+%d/%m/%Y')
HORA=$(date '+%H:%M')
DIA=$(date '+%A' | sed 's/Monday/Segunda/;s/Tuesday/Terça/;s/Wednesday/Quarta/;s/Thursday/Quinta/;s/Friday/Sexta/;s/Saturday/Sábado/;s/Sunday/Domingo/')

CONTAINERS=$(docker ps --format "{{.Names}}:{{.Status}}" | grep -c "Up")
TOTAL=$(docker ps -a --format "{{.Names}}" | wc -l | tr -d ' ')

OLLAMA_STATUS=$(curl -s --max-time 3 http://192.168.8.124:11434/api/tags 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('models',[])),'modelos')" 2>/dev/null || echo "offline")

GENIE_STATUS=$(curl -s --max-time 3 http://localhost:8000/health 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "offline")

BACKUP_LAST=$(ls -t /Volumes/JARVIS-COLD/backups/ 2>/dev/null | head -1 || echo "nenhum")

MSG="🌅 *Bom dia, Wagner\!*
─────────────────
📅 *$DIA, $DATE — $HORA*

*📊 Status J.A.R.V.I.S.*
✅ Containers: $CONTAINERS/$TOTAL online
✅ VISION Ollama: $OLLAMA_STATUS
✅ Genie Orchestrator: $GENIE_STATUS
✅ Último backup: $BACKUP_LAST
─────────────────
*🎯 Pilares ativos hoje*
- Imortalidade: Planos A/B/C/D operacionais
- Adaptabilidade: Cost Router Groq→Gemini→Deepseek→Ollama
- Conectividade: Telegram @hubOSTelegrambot online

*💡 Para começar:*
Me manda qualquer pedido — simples ou complexo.
Missão dada é missão cumprida\."

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}&parse_mode=MarkdownV2" > /dev/null

echo "[$(date)] Briefing enviado"
