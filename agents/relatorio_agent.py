#!/usr/bin/env python3
"""
JARVIS Relatorio Mensal Cliente WPS Digital
Trigger: !relatorio [cliente] ou automatico todo dia 5
"""
import sys, os, warnings, json, requests
from datetime import datetime
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

def gerar_relatorio_cliente(cliente: str) -> str:
    mes_ano = datetime.now().strftime("%B %Y")
    
    r = ask(
        f"""Gere um relatorio mensal de seguranca para o cliente WPS Digital:
Cliente: {cliente}
Mes: {mes_ano}

Inclua:
1. Resumo executivo (2 linhas)
2. Cameras operacionais (simule dados realistas)
3. Uptime do sistema (porcentagem)
4. Acessos registrados no mes (simule numeros)
5. Alertas de seguranca e como foram tratados
6. Manutencoes realizadas
7. Recomendacao para proximo mes
8. Proxima visita preventiva agendada

Formato profissional para sindico. Use dados simulados realistas para WPS Digital.""",
        system="Voce e o JARVIS gerando relatorio mensal WPS Digital. Seja profissional e especifico."
    )
    
    relatorio = f"""RELATORIO MENSAL WPS DIGITAL
Cliente: {cliente}
Periodo: {mes_ano}
Gerado em: {datetime.now().strftime("%d/%m/%Y %H:%M")}

{r.get("content","")}

---
WPS Digital | wagner@wps.com.br | (19) XXXX-XXXX
25 anos em seguranca eletronica condominial"""
    
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.colors import HexColor, white
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
        from reportlab.lib.units import cm
        import hashlib
        
        os.makedirs("/tmp/relatorios_wps", exist_ok=True)
        pdf_path = f"/tmp/relatorios_wps/relatorio_{hashlib.md5(cliente.encode()).hexdigest()[:8]}_{datetime.now().strftime('%Y%m')}.pdf"
        
        doc = SimpleDocTemplate(pdf_path, pagesize=A4,
            rightMargin=2*cm, leftMargin=2*cm, topMargin=2*cm, bottomMargin=2*cm)
        styles = getSampleStyleSheet()
        azul = HexColor("#1B4F8A")
        titulo_style = ParagraphStyle("titulo", parent=styles["Title"], textColor=azul, fontSize=16)
        normal = styles["Normal"]
        
        story = [
            Paragraph("WPS DIGITAL — RELATORIO MENSAL", titulo_style),
            Paragraph(f"Cliente: {cliente} | {mes_ano}", normal),
            Spacer(1, 0.5*cm),
        ]
        for linha in r.get("content","").split("\n"):

            if linha.strip():
                story.append(Paragraph(linha, normal))
            else:
                story.append(Spacer(1, 0.2*cm))
        
        doc.build(story)
        notify(f"Relatorio mensal gerado:\nCliente: {cliente}\nPDF: {pdf_path}")
        return relatorio + f"\n\nPDF: {pdf_path}"
    except:
        notify(f"Relatorio mensal:\n{relatorio[:2000]}")
        return relatorio

def listar_clientes_odoo():
    try:
        r = requests.post("http://localhost:18070/web/dataset/call_kw",
            json={"jsonrpc":"2.0","method":"call","params":{
                "model":"res.partner","method":"search_read",
                "args":[[["customer_rank",">",0]]],
                "kwargs":{"fields":["name","email"],"limit":20}
            }}, timeout=10)
        return r.json().get("result",[]) or []
    except: return []

def run(query: str) -> str:
    q = query.strip()
    if not q or q.lower() in ["todos","all","automatico"]:
        clientes = listar_clientes_odoo()
        if clientes:
            results = []
            for c in clientes[:5]:
                nome = c.get("name","Cliente")
                r = gerar_relatorio_cliente(nome)
                results.append(f"OK: {nome}")
            return f"Relatorios gerados: {len(results)} clientes\n" + "\n".join(results)
        else:
            return gerar_relatorio_cliente("Condominio Demo WPS Digital")
    else:
        return gerar_relatorio_cliente(q)

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Condominio Jardins Campinas"
    print(run(q)[:500])
