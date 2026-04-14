
def update_odoo_lead(lead_id: int, stage: str, notes: str = "") -> bool:
    """Atualiza status de lead no Odoo CRM"""
    import requests as _req, os
    from dotenv import load_dotenv
    load_dotenv("/Users/jarvis001/jarvis/.env")
    
    ODOO_URL = "http://localhost:18070"
    ODOO_DB = "odoo"
    ODOO_USER = "wagner@wps.com.br"
    ODOO_PASS = "odoowps"
    
    stage_map = {
        "novo": 1, "qualificado": 2, "proposta": 3,
        "negociacao": 4, "ganho": 5, "perdido": 6
    }
    
    try:
        # Login
        auth = _req.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc":"2.0","method":"call","params":{
                "model":"res.users","method":"authenticate",
                "args":[ODOO_DB, ODOO_USER, ODOO_PASS, {}],"kwargs":{}
            }}, timeout=10).json().get("result")
        if not auth: return False
        
        # Atualiza stage
        stage_id = stage_map.get(stage.lower(), 1)
        vals = {"stage_id": stage_id}
        if notes:
            vals["description"] = notes
        
        _req.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc":"2.0","method":"call","params":{
                "model":"crm.lead","method":"write",
                "args":[[lead_id], vals],"kwargs":{}
            }}, timeout=10)
        return True
    except: return False

def get_pipeline_odoo() -> list:
    """Retorna pipeline atual do CRM Odoo"""
    import requests as _req, os
    from dotenv import load_dotenv
    load_dotenv("/Users/jarvis001/jarvis/.env")
    
    ODOO_URL = "http://localhost:18070"
    
    try:
        auth = _req.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc":"2.0","method":"call","params":{
                "model":"res.users","method":"authenticate",
                "args":["odoo","wagner@wps.com.br","odoowps",{}],"kwargs":{}
            }}, timeout=10).json().get("result")
        if not auth: return []
        
        r = _req.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc":"2.0","method":"call","params":{
                "model":"crm.lead","method":"search_read",
                "args":[[["active","=",True]]],
                "kwargs":{"fields":["name","partner_name","expected_revenue","stage_id","user_id"],"limit":20}
            }}, timeout=10)
        return r.json().get("result",[]) or []
    except: return []

#!/usr/bin/env python3
"""
Agente Pipeline Odoo — analisa pedidos/faturas automaticamente
Chamado pelo webhook n8n quando evento Odoo ocorre
"""
import sys, os, warnings, json, requests
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage

load_dotenv("/Users/jarvis001/jarvis/.env")
GROQ_KEY = os.getenv("GROQ_API_KEY")
BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")
VISION_URL = "http://192.168.8.124:5006"

llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.1)

def notify(msg):
    try:
        requests.post(
            f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"},
            timeout=10
        )
    except: pass

def get_rag_context(query):
    try:
        r = requests.post(f"{VISION_URL}/search-and-generate",
            json={"query": query, "prompt": f"Contexto relevante sobre: {query}",
                  "model": "qwen2.5:7b", "limit": 2},
            timeout=20)
        if r.status_code == 200:
            return r.json().get("response", "")[:400]
    except: pass
    return ""

def analyze_sale_order(data):
    partner = data.get("partner_name", data.get("partner_id", "?"))
    amount = data.get("amount_total", data.get("amount", "?"))
    order_name = data.get("name", data.get("order_name", "?"))
    state = data.get("state", "confirmed")
    lines = data.get("order_lines", data.get("lines", []))
    
    context = get_rag_context(f"cliente {partner} WPS Digital condominio")
    
    response = llm.invoke([
        SystemMessage(content=f"""Você é o agente executivo JARVIS da WPS Digital.
Analise este pedido de venda e forneça um briefing executivo conciso para Wagner Silva.
Contexto do negócio: {context[:300]}
Seja direto: valor, cliente, prioridade, próximo passo recomendado."""),
        HumanMessage(content=f"""Pedido: {order_name}
Cliente: {partner}
Valor: R$ {amount}
Status: {state}
Itens: {json.dumps(lines)[:200] if lines else "não informado"}

Forneça briefing executivo em 3-4 linhas.""")
    ])
    
    msg = f"""🛒 *Pedido Confirmado — WPS Digital*

📋 *{order_name}*
👤 Cliente: {partner}
💰 Valor: R$ {amount}
📊 Status: {state}

🤖 *Análise JARVIS:*
{response.content[:400]}"""
    
    notify(msg)
    return {"ok": True, "analysis": response.content}

def analyze_invoice(data):
    partner = data.get("partner_name", data.get("partner_id", "?"))
    amount = data.get("amount_total", data.get("amount", "?"))
    invoice_name = data.get("name", data.get("invoice_name", "?"))
    move_type = data.get("move_type", "out_invoice")
    payment_state = data.get("payment_state", "not_paid")
    
    emoji = "✅" if payment_state == "paid" else "⏳"
    tipo = "Fatura" if "out_invoice" in move_type else "Documento"
    
    response = llm.invoke([
        SystemMessage(content="Você é o agente financeiro JARVIS da WPS Digital. Analise esta fatura em 2 linhas: situação e próximo passo."),
        HumanMessage(content=f"Fatura: {invoice_name}, Cliente: {partner}, Valor: R$ {amount}, Pagamento: {payment_state}")
    ])
    
    msg = f"""{emoji} *{tipo} Postada — WPS Digital*

📄 *{invoice_name}*
👤 Cliente: {partner}
💰 Valor: R$ {amount}
💳 Pagamento: {payment_state}

🤖 *JARVIS:* {response.content[:200]}"""
    
    notify(msg)
    return {"ok": True, "analysis": response.content}

def process_event(event_type, data):
    print(f"[OdooAgent] Evento: {event_type} — {json.dumps(data)[:100]}")
    if "sale" in event_type.lower() or "order" in event_type.lower():
        return analyze_sale_order(data)
    elif "invoice" in event_type.lower() or "account" in event_type.lower():
        return analyze_invoice(data)
    else:
        notify(f"📡 *Evento Odoo:* {event_type}\n```{json.dumps(data, indent=2)[:300]}```")
        return {"ok": True}

if __name__ == "__main__":
    # Teste local
    test_data = {
        "name": "SO/2026/0042",
        "partner_name": "Condominio Residencial Primavera",
        "amount_total": 15800.00,
        "state": "sale",
        "order_lines": ["CFTV 16 cameras Hikvision", "Controle de acesso biometrico", "Instalacao e configuracao"]
    }
    print("Testando analyze_sale_order...")
    result = analyze_sale_order(test_data)
    print(f"Resultado: {result}")
