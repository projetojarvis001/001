#!/usr/bin/env python3
"""
JARVIS Cobranca Agent — Monitora inadimplencia e dispara alertas
Trigger: !cobranca [verificar/listar/relatorio]
"""
import sys, os, warnings, json, requests
from datetime import datetime, timedelta
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
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0)
    def ask(q, system="", **kwargs):
        return {"ok": True, "content": _llm.invoke([HumanMessage(content=q)]).content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")
ODOO_URL = "http://localhost:18070"
ODOO_DB = "odoo"
ODOO_USER = "wagner@wps.com.br"
ODOO_PASS = "odoowps"

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def odoo_login():
    try:
        r = requests.post(f"{ODOO_URL}/web/dataset/call_kw",
            json={"jsonrpc":"2.0","method":"call","params":{
                "model":"res.users","method":"authenticate",
                "args":[ODOO_DB, ODOO_USER, ODOO_PASS, {}],"kwargs":{}
            }}, timeout=10)
        return r.json().get("result")
    except: return None

def get_faturas_vencidas():
    try:
        uid = odoo_login()
        if not uid: return []
        hoje = datetime.now().strftime("%Y-%m-%d")
        r = requests.post(f"{ODOO_URL}/web/dataset/call_kw",
            json={"jsonrpc":"2.0","method":"call","params":{
                "model":"account.move","method":"search_read",
                "args":[[
                    ["move_type","=","out_invoice"],
                    ["payment_state","in",["not_paid","partial"]],
                    ["invoice_date_due","<",hoje],
                    ["state","=","posted"]
                ]],
                "kwargs":{"fields":["name","partner_id","amount_residual","invoice_date_due"],"limit":50}
            }}, timeout=20)
        return r.json().get("result",[]) or []
    except:
        return []

def get_dias_atraso(data_vencimento):
    try:
        venc = datetime.strptime(data_vencimento, "%Y-%m-%d")
        return (datetime.now() - venc).days
    except: return 0

def gerar_mensagem_cobranca(cliente, valor, dias, nivel):
    templates = {
        5:  f"Ola, notamos que a fatura WPS Digital de R${valor:,.2f} venceu ha {dias} dias. Podemos regularizar?",
        10: f"Prezado cliente, a fatura WPS de R${valor:,.2f} esta em aberto ha {dias} dias. Para evitar interrupcao do servico, por favor regularize.",
        20: f"URGENTE: Fatura WPS R${valor:,.2f} vencida ha {dias} dias. Sem regularizacao em 10 dias o NOC sera suspenso.",
        30: f"AVISO FINAL: Fatura WPS R${valor:,.2f} ({dias} dias em atraso). Suspensao total do sistema em 15 dias se nao regularizado.",
    }
    for limite, msg in sorted(templates.items(), reverse=True):
        if dias >= limite: return msg
    return None

def verificar_inadimplencia():
    faturas = get_faturas_vencidas()
    
    if not faturas:
        notify("Cobranca: Nenhuma fatura vencida encontrada no Odoo.")
        return "Nenhuma fatura vencida."
    
    alertas = []
    for fatura in faturas:
        dias = get_dias_atraso(fatura.get("invoice_date_due",""))
        cliente = fatura.get("partner_id",["",""])[1] if isinstance(fatura.get("partner_id"),list) else "?"
        valor = fatura.get("amount_residual",0)
        
        msg = gerar_mensagem_cobranca(cliente, valor, dias, dias)
        if msg:
            alertas.append({
                "cliente": cliente,
                "fatura": fatura.get("name","?"),
                "valor": valor,
                "dias": dias,
                "mensagem": msg
            })
    
    if alertas:
        resumo = f"Cobranca — {len(alertas)} faturas vencidas:\n"
        for a in alertas[:5]:
            resumo += f"  {a['cliente']}: R${a['valor']:,.2f} ({a['dias']}d)\n"
        notify(resumo)
        
        for a in alertas:
            notify(f"Alerta cobranca:\nCliente: {a['cliente']}\nFatura: {a['fatura']}\nValor: R${a['valor']:,.2f}\nAtraso: {a['dias']} dias\nMensagem sugerida: {a['mensagem']}")
    
    return f"{len(alertas)} faturas vencidas processadas."

def run(query: str) -> str:
    q = query.lower().strip()
    if any(w in q for w in ["verificar","check","inadimpl","vencid","cobrar"]):
        return verificar_inadimplencia()
    elif any(w in q for w in ["listar","lista","relatorio"]):
        faturas = get_faturas_vencidas()
        if not faturas:
            return "Nenhuma fatura vencida no Odoo."
        linhas = [f"Faturas vencidas ({len(faturas)}):"]
        for f in faturas[:10]:
            dias = get_dias_atraso(f.get("invoice_date_due",""))
            cliente = f.get("partner_id",["",""])[1] if isinstance(f.get("partner_id"),list) else "?"
            linhas.append(f"  {cliente}: R${f.get('amount_residual',0):,.2f} ({dias}d)")
        result = "\n".join(linhas)
        notify(result)
        return result
    else:
        return verificar_inadimplencia()

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "verificar"
    print(run(q))
