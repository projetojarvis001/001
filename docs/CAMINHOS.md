# CAMINHOS E CONEXOES
Gerado: 2026-04-14 00:58

## ARQUIVOS CRITICOS JARVIS 192.168.8.121
/Users/jarvis001/jarvis/
  .env                         TODAS as API keys credenciais
  docker-compose.yml           13 containers Docker
  agents/
    jarvis_agent.py            Agente principal LangGraph RAG v2.0
    jarvis_context.py          SYSTEM_PROMPT_JARVIS WAGNER_CONTEXT
    cost_router.py             Cost Router 5 providers
    intel_agent.py             CNPJ CEP Selic 4 APIs
    autonomous_agent.py        Agente Autonomo LangGraph
    approval_system.py         SIM/NAO Telegram niveis 1-5
    prospect_agent.py          Leads condominiais
    financial_agent.py         MRR Odoo relatorio
    network/outlook/odoo/hunter/auto/intel/prospect/financial _server.py
  core/src/server.ts           Bot Telegram + rotas HTTP
  scripts/
    relatorio_diario.sh        7h crontab
    hunter_report.sh           9h crontab
    relatorio_semanal.sh       segunda 8h
    monitor_proativo.sh        cada 5min
    monitor_vision.sh          cada 10min
    raid_monitor.sh            cada 3min
    raid_sync.sh               cada 1h
    obsidian_watcher.sh        continuo 30s loop
  grafana/dashboard_executivo.json
  docs/ BLUEPRINT VERDADE SENHAS CAMINHOS AGENTES

## ARQUIVOS CRITICOS VISION 192.168.8.124
/Users/vision/jarvis-vision/
  semantic_api.py              API RAG :5006
  litellm_proxy.py             LocalAI proxy :8080

## LAUNCHAGENTS JARVIS ~/Library/LaunchAgents/
com.jarvis.agent.server        :7777
com.jarvis.network.server      :7778
com.jarvis.outlook.server      :7779
com.jarvis.odoo.server         :7780
com.jarvis.hunter.server       :7781
com.jarvis.auto.server         :7782
com.jarvis.intel.server        :7783
com.jarvis.prospect.server     :7784
com.jarvis.financial.server    :7785
com.jarvis.tunnel.vault        SSH :18200
com.jarvis.tunnel.keycloak     SSH :18080
com.jarvis.tunnel.odoo         SSH :18070
com.jarvis.obsidian.watcher    Obsidian

## DOCKER CONTAINERS JARVIS
jarvis-jarvis-core-1   Bot Telegram rotas :3000
jarvis-postgres-1      PostgreSQL pgvector KB
redis                  Cache BullMQ
jarvis-grafana-1       Grafana executivo :3001
obs_grafana            Grafana observabilidade :3300
obs_loki               Loki logs :3100
obs_promtail           Promtail coleta logs
n8n                    Workflows :5678
prometheus             Metricas :9090
vault                  HashiCorp Vault
keycloak               Auth

## PORTAS EM USO
3000  jarvis-core bot
3001  Grafana executivo
3100  Loki
3300  Grafana obs
5006  VISION RAG API
5678  n8n
7777  jarvis-agent
7778  network-agent
7779  outlook-agent
7780  odoo-agent
7781  hunter-agent
7782  auto-agent
7783  intel-agent
7784  prospect-agent
7785  financial-agent
8080  LocalAI proxy VISION
9090  Prometheus
11434 Ollama VISION
18070 Odoo tunnel
18080 Keycloak tunnel
18200 Vault tunnel

## FLUXO PRINCIPAL
Wagner Telegram
  -> Bot Core :3000 Docker
  -> roteia por comando
  -> Agente Python :7777-7785
  -> Cost Router Groq Claude Gemini LocalAI Ollama
  -> VISION RAG :5006
  -> resposta
  -> Telegram Wagner

## FLUXO ODOO
Odoo evento -> n8n :5678 -> /agent :3000 -> odoo-agent :7780 -> Telegram

## FLUXO OBSIDIAN
nota.md -> ~/Documents/JARVIS_KB -> watcher 30s -> POST /ingest VISION -> pgvector
