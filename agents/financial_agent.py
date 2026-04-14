#!/usr/bin/env python3
"""
Agente Financeiro JARVIS — MRR real do Odoo
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
    r = requests.post(f"{ODOO_URL}/web/dataset/call_kw",
        json={"jsonrpc":"2.0","method":"call","params":{
            "model":"res.users","method":"authenticate",
            "args":[ODOO_DB, ODOO_USER, ODOO_PASS, {}],"kwargs":{}
        }}, timeout=15)
    return r.json().get("result")

def odoo_call(uid, model, method, args=[], kwargs={}):
    r = requests.post(f"{ODOO_URL}/web/dataset/call_kw",
        json={"jsonrpc":"2.0","method":"call","params":{
            "model":model,"method":method,
            "args":args,"kwargs":kwargs
        }},
        cookies={"session_id": uid} if isinstance(uid, str) else {},
        timeout=30)
    return r.json().get("result")

def get_mrr():
    try:
        uid = odoo_login()
        if not uid:
            return {"error": "login falhou"}
        
        # Busca contratos recorrentes / subscricoes
        contracts = odoo_call(uid, "sale.order", "search_read",
            args=[[["state", "=", "sale"], ["recurring_invoice", "=", True]]],
            kwargs={"fields": ["name", "partner_id", "amount_total", "recurring_next_date"], "limit": 100})
        
        if not contracts:
            # Fallback: busca pedidos do mes
            from datetime import datetime, timedelta
            primeiro_mes = datetime.now().replace(day=1).strftime("%Y-%m-%d")
            contracts = odoo_call(uid, "sale.order", "search_read",
                args=[[["state", "=", "sale"], ["date_order", ">=", primeiro_mes]]],
                kwargs={"fields": ["name", "partner_id", "amount_total"], "limit": 50})
        
        if contracts and isinstance(contracts, list):
            total = sum(c.get("amount_total", 0) for c in contracts)
            return {
                "mrr": total,
                "contratos": len(contracts),
                "clientes": [c.get("partner_id", ["",""])[1] if isinstance(c.get("partner_id"), list) else "" for c in contracts[:5]]
            }
    except Exception as e:
        return {"error": str(e)[:100]}
    return {"mrr": 0, "contratos": 0}

def financial_report():
    data = get_mrr()
    if "error" in data:
        # Usa dados do KB como fallback
        report = ask(
            "Qual o MRR atual da WPS Digital e quais sao os KPIs financeiros?",
            system="Voce e o JARVIS. Use os dados do knowledge base."
        )
        return report.get("content","Dados financeiros nao disponiveis")
    
    mrr = data.get("mrr", 0)
    contratos = data.get("contratos", 0)
    clientes = data.get("clientes", [])
    
    analysis = ask(
        f"MRR Odoo: R${mrr:,.2f} | Contratos ativos: {contratos} | Top clientes: {clientes}. Analise executiva em 3 linhas com proximo passo.",
        system="Voce e o JARVIS CFO assistant de Wagner Silva."
    )
    
    report = f"Relatorio Financeiro\nMRR: R${mrr:,.2f}\nContratos: {contratos}\n{analysis.get('content','')}"
    notify(report)
    return report

def run(query="mrr"):
    return financial_report()

if __name__ == "__main__":
    print(run())
