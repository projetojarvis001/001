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


def gerar_pdf(dados: dict, proposta_texto: str) -> str:
    """Gera PDF real da proposta usando ReportLab"""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.colors import HexColor, white, black
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.units import cm
        import os, hashlib
        from datetime import datetime

        os.makedirs("/tmp/propostas_wps", exist_ok=True)
        nome_arquivo = f"/tmp/propostas_wps/proposta_{hashlib.md5(dados.get('condominio','x').encode()).hexdigest()[:8]}_{datetime.now().strftime('%Y%m%d')}.pdf"
        
        doc = SimpleDocTemplate(nome_arquivo, pagesize=A4,
            rightMargin=2*cm, leftMargin=2*cm, topMargin=2*cm, bottomMargin=2*cm)
        
        styles = getSampleStyleSheet()
        azul_wps = HexColor("#1B4F8A")
        
        titulo = ParagraphStyle("titulo", parent=styles["Title"],
            textColor=azul_wps, fontSize=18, spaceAfter=12)
        subtitulo = ParagraphStyle("subtitulo", parent=styles["Heading2"],
            textColor=azul_wps, fontSize=13, spaceAfter=8)
        normal = styles["Normal"]
        
        story = []
        
        # Header
        story.append(Paragraph("WPS DIGITAL", titulo))
        story.append(Paragraph("Seguranca Eletronica para Condomínios — 25 anos de mercado", normal))
        story.append(Spacer(1, 0.5*cm))
        
        # Dados do cliente
        story.append(Paragraph("PROPOSTA TECNICA E COMERCIAL", subtitulo))
        dados_table = [
            ["Cliente:", dados.get("condominio","?")],
            ["Data:", datetime.now().strftime("%d/%m/%Y")],
            ["Validade:", "30 dias"],
            ["Tipo:", dados.get("servico","Seguranca Eletronica")],
        ]
        t = Table(dados_table, colWidths=[4*cm, 12*cm])
        t.setStyle(TableStyle([
            ("BACKGROUND", (0,0), (0,-1), azul_wps),
            ("TEXTCOLOR", (0,0), (0,-1), white),
            ("FONTNAME", (0,0), (-1,-1), "Helvetica"),
            ("FONTSIZE", (0,0), (-1,-1), 10),
            ("GRID", (0,0), (-1,-1), 0.5, HexColor("#CCCCCC")),
            ("PADDING", (0,0), (-1,-1), 6),
        ]))
        story.append(t)
        story.append(Spacer(1, 0.5*cm))
        
        # Conteudo da proposta
        for linha in proposta_texto.split("\n"):
            if linha.strip():
                if linha.isupper() or linha.startswith("WPS") or linha.startswith("CLIENTE") or linha.startswith("SOLUCAO") or linha.startswith("INVESTIMENTO") or linha.startswith("RETORNO") or linha.startswith("DIFERENCIAL"):
                    story.append(Paragraph(linha, subtitulo))
                else:
                    story.append(Paragraph(linha, normal))
            else:
                story.append(Spacer(1, 0.2*cm))
        
        # Footer
        story.append(Spacer(1, 1*cm))
        story.append(Paragraph("wagner@wps.com.br | (19) XXXX-XXXX | wps.com.br", normal))
        story.append(Paragraph("WPS Digital — Sua seguranca e nossa missao ha 25 anos", normal))
        
        doc.build(story)
        return nome_arquivo
    except Exception as e:
        return f"ERRO PDF: {str(e)[:100]}"

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
    
    pdf_path = gerar_pdf(dados, proposta)
    if pdf_path.startswith("/tmp"):
        notify(f"*Proposta Gerada*\nCliente: {dados.get('condominio','?')}\nPDF: {pdf_path}\n\n{proposta[:1500]}")
    else:
        notify(f"*Proposta Gerada*\n{proposta[:3000]}")
    return proposta + f"\n\nPDF: {pdf_path}"

def run(query: str) -> str:
    return gerar_proposta(query)

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Condominio Villa Verde 120 unidades portaria virtual"
    print(run(q))
