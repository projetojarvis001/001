# ESTADO ATUAL JARVIS — 15/04/2026 22:15

## STATUS GERAL
SISTEMA COMPLETO — JARVIS + HERMES SHADOW OPERACIONAIS

## JARVIS
- 15 agentes :7777-:7791 operacionais
- KB 500 vetores pgvector hnsw scores 0.75+
- SYSTEM_PROMPT cirurgico identidade WPS Digital
- Cost Router 6 providers: Groq > Claude > Mistral > Gemma4 > LocalAI > Ollama
- Respostas com dados reais R$1.800 R$5.500 R$3.700

## HERMES SHADOW (NOVIDADE)
- Rodando no VISION :5009
- 20 interacoes registradas
- 1 skill criada: "Metas e Planejamento de Vendas WPS 2026"
- Cria nova skill automaticamente a cada 10 interacoes
- LaunchAgent ativo — sobe automaticamente no boot
- Model: gemma4:e4b (9.6GB no VISION)
- DB: ~/.hermes/jarvis_memory.db

## GEMMA4
- Instalado no VISION via Ollama 0.20.7
- Modelo: gemma4:e4b 9.6GB
- Ativo como fallback 3 no Cost Router
- Apache 2.0 gratuito

## ARQUITETURA ATUAL
Wagner → Telegram → JARVIS (relacoes publicas)
                        ↓
              executa 15 agentes + RAG 500 vetores
                        ↓
              loga no Hermes Shadow (sombra interna)
                        ↓
              Hermes aprende → cria skills → evolui

## PROXIMAS ACOES
1. Hermes Shadow acumular 100+ interacoes (passivo, automatico)
2. Instalar Hermes Agent CLI no VISION com config WPS
3. Adicionar gemma4 como modelo de embeddings alternativo
4. Testar Hermes Agent nativo com KB WPS via MCP

## INFRA
JARVIS: 192.168.8.121 Mac Mini M4
VISION: 192.168.8.124 Mac Mini M4 (Ollama + Shadow + Semantic API)
FRIDAY: 192.168.8.36 Dell 64GB
TADASH: 177.104.176.69 VM

## CREDENCIAIS
Postgres: jarvis_db jarvis_admin PG_PASSWORD no .env
Shadow: http://192.168.8.124:5009
Semantic: http://192.168.8.124:5006
Grafana: localhost:3001 admin/jarvis2026
