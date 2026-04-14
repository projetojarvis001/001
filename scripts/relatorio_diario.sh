#!/bin/bash
# relatorio_diario.sh — conteudo real WPS Digital
cd /Users/jarvis001/jarvis
export PYTHONPATH="/Users/jarvis001/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"

BOT=$(grep TELEGRAM_BOT_TOKEN .env | cut -d= -f2)
CHAT=$(grep TELEGRAM_CHAT_ID .env | cut -d= -f2)
DATA=$(date "+%d/%m/%Y %H:%M")

# Status agentes
ONLINE=0
for port in 7777 7778 7779 7780 7781 7782 7783 7784 7785 7786 7787 7788 7789 7790 7791; do
    curl -fsS http://localhost:$port > /dev/null 2>&1 && ONLINE=$((ONLINE+1))
done

# KB vetores
KB=$(curl -fsS http://192.168.8.124:5006/stats 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('vectors_total',0))" 2>/dev/null || echo "?")

# Agenda do dia
AGENDA=$(curl -s -X POST http://localhost:7788 -H "Content-Type: application/json" -d "{"task":"listar"}" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','Sem visitas')[:200])" 2>/dev/null || echo "Sem visitas agendadas")

# Cobrancas
COBRANCA=$(curl -s -X POST http://localhost:7789 -H "Content-Type: application/json" -d "{"task":"listar"}" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','OK')[:150])" 2>/dev/null || echo "OK")

MSG="JARVIS — Bom dia Wagner
Data: $DATA

SISTEMA
Agentes online: $ONLINE/15
KB: $KB vetores
VISION: $(curl -fsS http://192.168.8.124:5006/health 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if d.get('ok') else 'OFFLINE')" 2>/dev/null || echo 'verificar')

AGENDA DE HOJE
$AGENDA

FINANCEIRO
MRR atual: consultar !financeiro
Cobrancas: $COBRANCA

ACOES SUGERIDAS
1. !prospect condominio campinas taquaral
2. !cobranca verificar
3. !jarvis oportunidades desta semana

Use !jarvis para qualquer analise executiva."

curl -s -X POST "https://api.telegram.org/bot$BOT/sendMessage"     -H "Content-Type: application/json"     -d "{"chat_id":"$CHAT","text":"$MSG"}" > /dev/null

echo "[$(date)] Relatorio diario enviado"
