#!/usr/bin/env python3
"""
JARVIS Contract Agent — Gera proposta PDF personalizada
Trigger: !contrato [condominio] [unidades] [servico]
"""
import sys, os, warnings, json, requests
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

try:
    from cost_router import ask
except:
    from langchain_groq import ChatGroq
    from langchain_core.messages import HumanMessage
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0.2)
    def ask(q, system="", **kwargs):
        return {"ok": True, "content": _llm.invoke([HumanMessage(content=q)]).content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

PROPOSTA_TEMPLATE = """
WPS DIGITAL — PROPOSTA TECNICA E COMERCIAL
Empresa: WPS Digital — 25 anos em seguranca eletronica condominial
Contato: wagner@wps.com.br | (19) XXXX-XXXX | wps.com.br

CLIENTE: {condominio}
Data: {data}
Validade: 30 dias

DIAGNOSTICO:
{diagnostico}

SOLUCAO PROPOSTA — PACOTE {pacote}:
{solucao}

INVESTIMENTO:
{investimento}

RETORNO SOBRE INVESTIMENTO:
{roi}

DIFERENCIAIS WPS DIGITAL:
- NOC proprio 24/7 em Campinas (SLA 8 segundos)
- 25 anos de experiencia exclusiva em condomínios
- Integracao com sistemas condominiais (Condominio 21, Mega, Superlógica)
- Suporte local — nao call center nacional
- Garantia contratual com penalidade por SLA nao cumprido

APROVADO POR: Wagner Silva — Chairman WPS Digital
"""

def gerar_proposta(query: str) -> str:
    from datetime import datetime
    data = datetime.now().strftime("%d/%m/%Y")
    
    # Extrai informacoes da query
    analysis = ask(
        f"""Analise este pedido de proposta: "{query}"
        
Extraia e gere em JSON:
{{
  "condominio": "nome do condominio",
  "unidades": numero,
  "servico": "tipo principal (portaria_virtual/cftv/controle_acesso/completo)",
  "diagnostico": "2 linhas descrevendo a situacao atual e dor principal",
  "pacote": "BASICO/RECOMENDADO/PREMIUM",
  "solucao": "lista de equipamentos e servicos propostos",
  "investimento_instalacao": valor_numerico,
  "investimento_mensalidade": valor_numerico,
  "roi_meses": numero,
  "economia_mensal": valor_numerico
}}

Base de precos WPS:
- Portaria virtual: R$1.800/mes substitui porteiro R$5.500/mes
- CFTV basico 8 cameras: R$8.500
- CFTV medio 16 cameras 4MP: R$22.000
- CFTV completo 32 cameras: R$45.000
- Controle acesso facial: R$3.200 por ponto
- Mensalidade manutencao: R$800 a R$3.500/mes
Responda APENAS JSON valido.""",
        system="Especialista em propostas comerciais WPS Digital. Responda apenas JSON."
    )
    
    try:
        text = analysis.get("content","").strip()
        if "```" in text: text = text.split("```")[1].replace("json","").strip()
        dados = json.loads(text)
    except:
        dados = {
            "condominio": query,
            "unidades": "?",
            "diagnostico": "Sistema atual desatualizado, oportunidade de modernizacao",
            "pacote": "RECOMENDADO",
            "solucao": "CFTV 16 cameras 4MP + Portaria Virtual + Controle Acesso",
            "investimento_instalacao": 45000,
            "investimento_mensalidade": 2200,
            "roi_meses": 12,
            "economia_mensal": 3700
        }
    
    proposta = PROPOSTA_TEMPLATE.format(
        condominio=f"{dados.get('condominio','?')} — {dados.get('unidades','?')} unidades",
        data=data,
        diagnostico=dados.get("diagnostico",""),
        pacote=dados.get("pacote","RECOMENDADO"),
        solucao=dados.get("solucao",""),
        investimento=f"Instalacao: R${dados.get('investimento_instalacao',0):,.0f}\nMensalidade: R${dados.get('investimento_mensalidade',0):,.0f}/mes",
        roi=f"Economia mensal: R${dados.get('economia_mensal',0):,.0f}\nPayback: {dados.get('roi_meses',12)} meses\nEconomia 12 meses: R${dados.get('economia_mensal',0)*12:,.0f}"
    )
    
    notify(f"*Proposta Gerada*\n{proposta[:3000]}")
    return proposta

def run(query: str) -> str:
    return gerar_proposta(query)

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Condominio Villa Verde 120 unidades portaria virtual"
    print(run(q))
