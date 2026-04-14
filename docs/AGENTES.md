# AGENTES E FLUXOS
Gerado: 2026-04-14 00:58

## HIERARQUIA
Wagner Silva Chairman
  |
  | Telegram
  v
BOT CORE :3000 TypeScript
  |
  !jarvis    -> JARVIS AGENT :7777
  !rede      -> NETWORK AGENT :7778
  !outlook   -> OUTLOOK AGENT :7779
  !hunter    -> HUNTER AGENT :7781
  !auto      -> AUTO AGENT :7782
  !intel     -> INTEL AGENT :7783
  !prospect  -> PROSPECT AGENT :7784
  !financeiro-> FINANCIAL AGENT :7785
  SIM_/NAO_  -> AUTO AGENT /approve
  n8n evento -> ODOO AGENT :7780

## JARVIS AGENT :7777 FLUXO
INPUT mensagem Wagner
  -> [understand] detecta CNPJ/CEP? SIM -> intel_agent -> OUTPUT
  -> NAO -> [search_context] RAG VISION + get_memories
  -> [plan_and_respond] Cost Router + SYSTEM_PROMPT + RAG + memorias
  -> [should_execute?] SIM -> [execute_on_friday] bash SSH
  -> NAO -> [save_memory] -> OUTPUT Telegram

## COST ROUTER CADEIA
PERGUNTA
  -> try_groq OK? -> RESPOSTA llama-3.3-70b gratis
  -> FALHOU
  -> try_anthropic OK? -> RESPOSTA claude-sonnet-4 pago
  -> FALHOU
  -> try_gemini OK? -> RESPOSTA gemini-2.0-flash gratis
  -> FALHOU
  -> try_localai OK? -> RESPOSTA qwen3:8b proxy :8080
  -> FALHOU
  -> try_ollama OK? -> RESPOSTA qwen3:8b direto VISION
  -> FALHOU -> "Todos os providers falharam"

## INTEL AGENT :7783 FLUXO CNPJ
INPUT query com CNPJ
  -> try_opencnpj OK? -> dados
  -> FALHOU -> try_brasilapi OK? -> dados
  -> FALHOU -> try_receitaws OK? -> dados
  -> FALHOU -> try_cnpjws OK? -> dados
  -> formata: razao_social + situacao + atividade + capital + cidade + socios
  -> analise Groq 3 linhas executivas
  -> notify Telegram
  -> OUTPUT dados reais Receita Federal

## APROVACAO FLUXO
JARVIS detecta acao nivel 3+
  -> classify_risk analisa keywords
  -> nivel 1-2: executa automaticamente
  -> nivel 3-5: envia Telegram SIM_ID NAO_ID timeout 10min
  -> Wagner responde SIM_ID
  -> Bot Core POST /approve -> auto_server
  -> process_approval_response atualiza pending
  -> JARVIS executa acao

## PIPELINE ODOO FLUXO
Odoo evento pedido confirmado
  -> n8n webhook :5678
  -> HTTP POST /agent :3000 Body agent=odoo
  -> odoo-agent :7780 LangGraph
  -> analisa pedido consulta KB
  -> gera briefing executivo
  -> Telegram Wagner

## RAID FLUXO
CADA 3 MIN raid_monitor.sh
  -> check :7777 OK? -> log OK
  -> OFFLINE -> launchctl kickstart -> sleep 10
  -> check novamente OK? -> notify auto-recuperado
  -> AINDA OFFLINE -> notify ATENCAO JARVIS offline

CADA 1 HORA raid_sync.sh
  -> scp agentes criticos -> FRIDAY ~/jarvis_backup
  -> jarvis_agent.py jarvis_context.py cost_router.py
  -> autonomous_agent.py intel_agent.py .env

## OBSIDIAN FLUXO
Wagner escreve nota.md em ~/Documents/JARVIS_KB
  -> obsidian_watcher.sh detecta arquivo novo cada 30s
  -> le conteudo titulo igual nome arquivo
  -> POST /ingest VISION :5006
  -> pgvector gera embedding salva vetor
  -> proximo !jarvis usa conteudo automaticamente
