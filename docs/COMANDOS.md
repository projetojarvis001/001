# COMANDOS JARVIS — REFERENCIA COMPLETA
Atualizado: 2026-04-14 13:21-04-14 10:03-04-14 09:48

## TODOS OS COMANDOS DISPONIVEIS NO TELEGRAM

### Inteligencia e Negocio
!jarvis [pergunta]          — responde sobre negocio sistema analise
                              Ex: !jarvis qual o ticket medio WPS?
                              Ex: !jarvis status do sistema

### Dados Publicos
!intel [cnpj ou cep]        — consulta CNPJ dados Receita Federal ou CEP
                              Ex: !intel 60.746.948/0001-12
                              Ex: !intel 13049900

### Operacional
!rede [pergunta]            — diagnostico de rede via FRIDAY
!outlook [acao]             — acessa emails Microsoft Graph
!auto [objetivo]            — agente autonomo executa tarefas no servidor
!financeiro                 — MRR e relatorio financeiro do Odoo

### Mercado
!hunter [pergunta]          — analise cripto BTC ETH Fear&Greed
!prospect [keyword]         — busca leads condominiais no Google

### Comercial WPS
!contrato [desc]            — gera proposta PDF personalizada
                              Ex: !contrato Condominio X 120 unidades portaria virtual
!email [sindico condominio] — gera email follow-up pos visita
                              Ex: !email Carlos Villa Verde CFTV
!visita [desc ou listar]    — agenda visitas tecnicas
                              Ex: !visita Condominio X segunda 14h
                              Ex: !visita listar
!cobranca [verificar]       — monitora inadimplencia no Odoo
                              Ex: !cobranca verificar
                              Ex: !cobranca listar


### Relatorio e NPS
!relatorio [cliente]        — gera relatorio mensal PDF para cliente
                              Ex: !relatorio Condominio Jardins Campinas
!nps [cliente ou relatorio] — envia pesquisa NPS ou ve resultado
                              Ex: !nps Condominio Jardins
                              Ex: !nps relatorio

### Aprovacao (resposta automatica)
SIM_[ID]                    — aprova acao pendente nivel 3+
NAO_[ID]                    — rejeita acao pendente nivel 3+

## AGENTES E PORTAS

| Porta | Agente | Trigger | Funcao |
|---|---|---|---|
| 7777 | jarvis-agent | !jarvis | Orquestrador principal RAG memoria |
| 7778 | network-agent | !rede | Diagnostico rede FRIDAY |
| 7779 | outlook-agent | !outlook | Microsoft Graph emails |
| 7780 | odoo-agent | n8n webhook | Pipeline comercial Odoo |
| 7781 | hunter-agent | !hunter | Cripto BTC ETH Fear&Greed |
| 7782 | auto-agent | !auto | Agente autonomo LangGraph |
| 7783 | intel-agent | !intel | CNPJ CEP Selic APIs publicas |
| 7784 | prospect-agent | !prospect | Leads condominiais Google |
| 7785 | financial-agent | !financeiro | MRR Odoo relatorio |
| 7786 | contract-agent | !contrato | Proposta PDF personalizada |
| 7787 | email-agent | !email | Follow-up sindico pos visita |
| 7788 | agenda-agent | !visita | Agendamento visitas tecnicas |
| 7789 | cobranca-agent | !cobranca | Inadimplencia Odoo alertas |

## COST ROUTER — ORDEM DE PROVIDERS

1. Groq llama-3.3-70b      — primario gratis ilimitado
2. Anthropic Claude Sonnet — qualidade pago fallback 1
3. Mistral mistral-small   — gratis 1B tokens mes fallback 2
4. Gemini 2.0-flash        — gratis billing pendente fallback 3
5. LocalAI qwen3:8b        — local VISION fallback 4
6. Ollama qwen3:8b         — bunker offline fallback 5

## KNOWLEDGE BASE

- pgvector :5006 — 343+ vetores busca semantica
- LightRAG :5008 — 188+ docs grafo de conhecimento
- Obsidian ~/Documents/JARVIS_KB — auto-ingestao 30s

## ACESSO SERVICOS

| Servico | URL | Credencial |
|---|---|---|
| Grafana | localhost:3001 | admin / jarvis2026 |
| n8n | localhost:5678 | wagner@wps.com.br / jarvis2026 |
| Odoo | localhost:18070 | wagner@wps.com.br / odoowps |
| Grafana dashboard | /d/71fd7ffc... | - |
| Open WebUI | 192.168.8.124:3030 | - |
