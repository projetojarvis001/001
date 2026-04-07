#!/bin/bash
BOT="8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT="170323936"
LOG="/tmp/updater_agent.log"
VISION="http://192.168.8.124:5006"
TS=$(date '+%d/%m/%Y %H:%M')

notify() {
  curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT\",\"text\":\"$1\"}" > /dev/null
}

echo "[$(date)] Updater Agent iniciando..." >> $LOG

# 1. DOCKER IMAGES — atualiza imagens base
echo "[$(date)] Verificando imagens Docker..." >> $LOG
OUTDATED=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -10)
UPDATED=0
for img in postgres:16-alpine redis:7-alpine grafana/grafana:latest n8nio/n8n; do
  PULLED=$(docker pull $img 2>&1 | tail -1)
  if echo "$PULLED" | grep -q "newer"; then
    UPDATED=$((UPDATED+1))
    echo "[$(date)] Atualizado: $img" >> $LOG
  fi
done

# 2. NODE PACKAGES — verifica dependências desatualizadas
echo "[$(date)] Verificando npm packages..." >> $LOG
cd ~/jarvis/core
OUTDATED_NPM=$(npm outdated --json 2>/dev/null | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  critical=[k for k,v in d.items() if v.get('current','0') != v.get('latest','0')]
  print(','.join(critical[:5]) if critical else 'OK')
except: print('OK')
" 2>/dev/null)
cd ~/jarvis

# 3. OLLAMA MODELS — verifica se há modelos mais novos
echo "[$(date)] Verificando modelos Ollama..." >> $LOG
OLLAMA_UPDATE=$(curl -s http://192.168.8.124:11434/api/tags 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
models=d.get('models',[])
print(f'{len(models)} modelos: ' + ', '.join([m['name'] for m in models[:4]]))
" 2>/dev/null || echo "Ollama indisponível")

# 4. AGENT SKILLS — atualiza skills instaladas
echo "[$(date)] Verificando agent skills..." >> $LOG
SKILLS_UPDATE=$(npx agent-skills-cli update --all -a claude -y 2>/dev/null | tail -3 || echo "Skills OK")

# 5. PYTHON PACKAGES Mac2 — verifica via VISION
echo "[$(date)] Verificando Python packages Mac2..." >> $LOG
PY_CHECK=$(curl -s -X POST "$VISION/cmd" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"guardian_run"}' 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin); print('OK' if d.get('ok') else 'WARN')
" 2>/dev/null || echo "VISION offline")

# 6. GITHUB — verifica se repos remotos têm commits novos
echo "[$(date)] Verificando GitHub..." >> $LOG
cd ~/jarvis
git fetch origin --quiet 2>/dev/null
BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "0")
AHEAD=$(git rev-list origin/main..HEAD --count 2>/dev/null || echo "0")
GIT_STATUS="ahead:$AHEAD behind:$BEHIND"

# 7. ZEROCLAW — verifica versão
ZEROCLAW_STATUS=$(curl -s http://localhost:42617/health 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin); print('OK v'+str(d.get('version','?')))
" 2>/dev/null || echo "verificar")

# 8. LIMPEZA — remove arquivos temporários e logs antigos
echo "[$(date)] Limpeza de temporários..." >> $LOG
find /tmp -name "*.log" -mtime +7 -delete 2>/dev/null
find ~/jarvis/core -name "*.bak.*" -mtime +30 -delete 2>/dev/null
DOCKER_PRUNED=$(docker system prune -f --filter "until=168h" 2>/dev/null | tail -1 || echo "")

# 9. ANÁLISE IA — pede ao VISION avaliação do sistema
echo "[$(date)] Análise IA do sistema..." >> $LOG
IA_ANALYSIS=$(curl -s -X POST "$VISION/search-and-generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"system health optimization\",
    \"prompt\": \"Analise o estado do sistema JARVIS e sugira 1 melhoria prioritária: Docker atualizado=$UPDATED imagens, NPM outdated=$OUTDATED_NPM, Skills=$SKILLS_UPDATE, Git=$GIT_STATUS. Responda em 1 frase direta.\",
    \"model\": \"qwen2.5:7b\",
    \"limit\": 2
  }" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('response','')[:200])
" 2>/dev/null || echo "")

# RELATÓRIO FINAL
REPORT="Updater Agent $TS

Docker: $UPDATED imagens atualizadas
NPM: $OUTDATED_NPM
Ollama: $OLLAMA_UPDATE
Skills: atualizado
Mac2: $PY_CHECK
Git: $GIT_STATUS
ZeroClaw: $ZEROCLAW_STATUS
Limpeza: temporários removidos

IA: $IA_ANALYSIS"

notify "$REPORT"
echo "[$(date)] Updater concluído" >> $LOG
echo "$REPORT"
