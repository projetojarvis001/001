# PROJETO J.A.R.V.I.S. — BLUEPRINT GERAL
Gerado: 2026-04-14 00:58 | Versao: FINAL COMPLETO

## VISAO GERAL
Sistema de inteligencia executiva autonomo para Wagner Silva, Chairman do Grupo Wagner.
4 nos, 9 agentes especializados, 285+ vetores RAG, Cost Router 5 providers.
Principio: self-solving, zero intervencao humana.

## INFRAESTRUTURA
JARVIS  192.168.8.121 / 100.107.185.12  Mac Mini M4 16GB  Orquestrador
VISION  192.168.8.124 / 100.66.31.34    Mac Mini M4 16GB  IA local RAG
FRIDAY  192.168.8.36  / 100.118.208.78  Dell 64GB         Worker RAID backup
TADASH  177.104.176.69/ 100.67.82.123   VM 72vCPU 93GB    Odoo Keycloak Vault

## 9 AGENTES
:7777 jarvis-agent    !jarvis      Orquestrador RAG memoria episodica
:7778 network-agent   !rede        Diagnostico rede FRIDAY
:7779 outlook-agent   !outlook     Microsoft Graph emails
:7780 odoo-agent      n8n webhook  Pipeline comercial Odoo
:7781 hunter-agent    !hunter      Cripto BTC ETH Fear&Greed
:7782 auto-agent      !auto        Agente autonomo LangGraph
:7783 intel-agent     !intel       CNPJ CEP Selic APIs publicas
:7784 prospect-agent  !prospect    Leads condominiais DuckDuckGo
:7785 financial-agent !financeiro  MRR Odoo relatorio financeiro

## COST ROUTER
Groq llama-3.3-70b   primario gratuito rapido
Claude Sonnet 4      qualidade pago fallback 1
Gemini 2.0 Flash     gratuito fallback 2 (key pendente renovacao)
LocalAI :8080        proxy qwen3:8b local
Ollama VISION        bunker local sem internet

## KNOWLEDGE BASE
Total: 285+ vetores | Motor: pgvector PostgreSQL VISION
Embedding: nomic-embed-text | Geracao: qwen3:8b 5.2GB
Auto-ingestao: Obsidian ~/Documents/JARVIS_KB watcher 30s

## PIPELINE ODOO
Odoo evento -> n8n :5678 -> /agent :3000 -> odoo-agent :7780 -> Telegram

## APROVACAO
Nivel 1-2: AUTO executa sozinho
Nivel 3:   APROVACAO impacto moderado
Nivel 4:   APROVACAO impacto alto
Nivel 5:   CRITICA irreversivel
Fluxo: JARVIS envia SIM_ID/NAO_ID Telegram -> Wagner responde -> executa

## RAID
Monitor: raid_monitor.sh cada 3min - detecta queda, auto-recupera via launchctl
Sync: raid_sync.sh cada hora - copia agentes criticos para FRIDAY

## CRONTAB
7h diario       relatorio_diario.sh    status sistema Telegram
9h diario       hunter_report.sh       cripto BTC ETH Fear&Greed
8h segunda      relatorio_semanal.sh   MRR leads oportunidades
cada 5min       monitor_proativo.sh    health check
cada 10min      monitor_vision.sh      VISION check
cada 3min       raid_monitor.sh        failover check
cada 1h         raid_sync.sh           sync FRIDAY

## ACESSO RAPIDO
n8n       localhost:5678   wagner@wps.com.br / jarvis2026
Grafana   localhost:3001   admin / jarvis2026
Odoo      localhost:18070  wagner@wps.com.br / odoowps
Keycloak  localhost:18080  admin / wps@keycloak2026
Vault     localhost:18200  VAULT_TOKEN no .env
