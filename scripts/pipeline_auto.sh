#!/bin/bash
LOG="/tmp/pipeline_vendas.log"
echo "[$(date)] Pipeline autônomo iniciando..." >> $LOG

LEADS=$(~/zeroclaw/target/release/zeroclaw agent -m \
  "Liste 3 condomínios SP com 150+ unidades para prospecção WPS Digital. Responda SOMENTE em JSON array: [{\"nome\":\"...\",\"bairro\":\"...\",\"unidades\":200}]" \
  2>/dev/null | grep -o '\[.*\]' | head -1)

if [ -n "$LEADS" ]; then
    echo "$LEADS" | python3 -c "
import sys, json, subprocess
leads = json.loads(sys.stdin.read())
for lead in leads[:2]:
    lead['email'] = 'sindico@condominio.com.br'
    result = subprocess.run(
        ['python3', '/Users/jarvis001/jarvis/scripts/pipeline_vendas.py'],
        input=json.dumps(lead), capture_output=True, text=True,
        env={**__import__('os').environ, 'LEAD_JSON': json.dumps(lead)}
    )
    print(result.stdout[:200])
"
fi
echo "[$(date)] Pipeline concluído" >> $LOG
