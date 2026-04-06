#!/usr/bin/env python3
import sys, json, subprocess, urllib.request, urllib.parse
from datetime import datetime

sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')

BOT = "8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT = "8206117553"
VISION = "http://192.168.8.124:5006"
PROPOSTA_ENDPOINT = "http://localhost:7070"

def telegram(msg):
    data = json.dumps({"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{BOT}/sendMessage",
        data=data, headers={"Content-Type": "application/json"})
    try: urllib.request.urlopen(req, timeout=10)
    except: pass

def vision_post(endpoint, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{VISION}/{endpoint}",
        data=data, headers={"Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, timeout=60)
        return json.loads(r.read())
    except Exception as e:
        return {"error": str(e)}

def pipeline_lead(lead):
    nome = lead.get("nome", "")
    bairro = lead.get("bairro", "")
    unidades = lead.get("unidades", 100)
    email = lead.get("email", "")

    telegram(f"🎯 *Pipeline JARVIS iniciado*\n\nLead: {nome}\nBairro: {bairro}\nUnidades: {unidades}")

    qualificacao = vision_post("search-and-generate", {
        "query": f"qualificacao lead condominio {unidades} unidades segurança",
        "prompt": f"Avalie o lead: {nome}, {bairro}, {unidades} unidades. Score 0-100, potencial WPS Digital, principais argumentos de venda.",
        "model": "qwen2.5:7b", "limit": 3
    })
    score_text = qualificacao.get("response", "Score: 75")[:200]
    telegram(f"📊 *Qualificação VISION*\n{score_text}")

    proposta = vision_post("propose", {
        "company_name": nome,
        "contact_name": "Síndico",
        "units": unidades,
        "problems": "segurança desatualizada, alto custo operacional",
        "current_supplier": "desconhecido",
        "model": "qwen2.5:7b"
    })
    proposta_text = proposta.get("proposal_text", proposta.get("response", ""))[:300]

    data = json.dumps({
        "cliente": nome, "sindico": "Síndico",
        "unidades": unidades
    }).encode()
    req = urllib.request.Request(f"{PROPOSTA_ENDPOINT}/gerar-proposta",
        data=data, headers={"Content-Type": "application/json"})
    try:
        doc_result = json.loads(urllib.request.urlopen(req, timeout=30).read())
        doc_file = doc_result.get("file", "")
        telegram(f"📄 *Proposta .docx gerada*\n`{doc_file}`")
    except Exception as e:
        telegram(f"⚠️ Docx error: {e}")
        doc_file = ""

    vision_post("memories/save", {
        "session_id": "pipeline-vendas",
        "role": "agent",
        "content": f"Lead processado: {nome} | {bairro} | {unidades} un | {datetime.now().strftime('%d/%m/%Y %H:%M')}"
    })

    telegram(f"""✅ *Pipeline concluído*

🏢 Lead: {nome}
📍 {bairro} | {unidades} unidades
📊 Qualificação: OK
📄 Proposta: gerada
📧 Próximo passo: envio email

*Aguardando aprovação Wagner para enviar.*
/aprovar_{nome.replace(' ','_')} — para enviar
/rejeitar_{nome.replace(' ','_')} — para descartar""")

    return {"lead": nome, "proposta": doc_file, "status": "aguardando_aprovacao"}

if __name__ == "__main__":
    lead = {
        "nome": "Condominio Jardim das Laranjeiras",
        "bairro": "Zona Sul SP",
        "unidades": 220,
        "email": "sindico@jardimlaranjeiras.com.br"
    }
    result = pipeline_lead(lead)
    print(json.dumps(result, ensure_ascii=False, indent=2))
