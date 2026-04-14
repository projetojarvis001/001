#!/usr/bin/env python3
"""
JARVIS Email Agent — Follow-up automatico pos visita tecnica
Trigger: !email [nome_sindico] [condominio] [tipo_proposta]
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
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0.3)
    def ask(q, system="", **kwargs):
        return {"ok": True, "content": _llm.invoke([HumanMessage(content=q)]).content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

EMAILS = {
    "d1": {
        "assunto": "Proposta WPS Digital — {condominio}",
        "corpo": """Prezado(a) {sindico},

Foi um prazer visitar o {condominio} hoje.

Conforme conversamos, preparei uma proposta personalizada com base no que identifiquei na visita tecnica.

Resumo da solucao recomendada:
{solucao}

Investimento: {investimento}
Retorno estimado: {roi}

A proposta completa com projeto tecnico e especificacoes esta em anexo.

Fico a disposicao para tirar qualquer duvida.
Quando voce tem disponibilidade para uma conversa rapida sobre a proposta?

Atenciosamente,
Wagner Silva
WPS Digital — 25 anos em seguranca condominial
(19) XXXX-XXXX | wagner@wps.com.br"""
    },
    "d4": {
        "assunto": "Case de Sucesso — Condominio similar ao {condominio}",
        "corpo": """Prezado(a) {sindico},

Queria compartilhar um case de sucesso de um condominio muito similar ao {condominio}.

O Condominio Jardins Campinas (180 apartamentos) reduziu seu custo de portaria de R$28.000/mes para R$3.200/mes com nossa portaria virtual.
ROI atingido em 8 meses.

Isso representa uma economia de R$297.600 nos primeiros 3 anos.

Posso fazer os mesmos calculos para o {condominio}?

Wagner Silva — WPS Digital"""
    },
    "d7": {
        "assunto": "Pergunta rapida sobre a proposta — {condominio}",
        "corpo": """Prezado(a) {sindico},

Passando para saber se teve oportunidade de avaliar a proposta que enviei.

Caso tenha alguma duvida ou queira ajustar algum item, estou aqui.

Posso tambem apresentar a proposta para o conselho do condominio se preferir.

Wagner Silva — WPS Digital"""
    }
}


def enviar_email_real(destinatario: str, assunto: str, corpo: str) -> bool:
    """Envia email real via Microsoft Graph OAuth2"""
    import os, requests as _req
    
    CLIENT_ID = os.getenv("AZURE_CLIENT_ID","")
    CLIENT_SECRET = os.getenv("AZURE_CLIENT_SECRET","")
    TENANT_ID = os.getenv("AZURE_TENANT_ID","")
    
    if not all([CLIENT_ID, CLIENT_SECRET, TENANT_ID]):
        print("[Email] Credenciais Azure nao configuradas — email salvo localmente")
        return False
    
    try:
        # Obtem token
        token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
        token_r = _req.post(token_url, data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope": "https://graph.microsoft.com/.default"
        }, timeout=10)
        token = token_r.json().get("access_token")
        if not token: return False
        
        # Envia email
        email_r = _req.post(
            "https://graph.microsoft.com/v1.0/users/wagner@wps.com.br/sendMail",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json={"message": {
                "subject": assunto,
                "body": {"contentType": "Text", "content": corpo},
                "toRecipients": [{"emailAddress": {"address": destinatario}}]
            }},
            timeout=15
        )
        return email_r.status_code == 202
    except Exception as e:
        print(f"[Email] Erro Graph: {e}")
        return False

def gerar_email(query: str, dia: str = "d1") -> dict:
    from datetime import datetime
    
    analysis = ask(
        f"""Extraia do pedido: "{query}"
JSON: {{"sindico":"nome","condominio":"nome","solucao":"servico principal","investimento":"R$X","roi":"X meses"}}
Responda APENAS JSON.""",
        system="Assistente comercial WPS Digital."
    )
    
    try:
        text = analysis.get("content","").strip()
        if "```" in text: text = text.split("```")[1].replace("json","").strip()
        dados = json.loads(text)
    except:
        dados = {"sindico":"Sindico","condominio":query,"solucao":"Portaria Virtual + CFTV","investimento":"R$45.000","roi":"12 meses"}
    
    template = EMAILS.get(dia, EMAILS["d1"])
    assunto = template["assunto"].format(**dados)
    corpo = template["corpo"].format(**dados)
    
    # Tenta enviar via Graph se destinatario fornecido
    email_sindico = dados.get("email", "")
    if email_sindico and "@" in email_sindico:
        enviado = enviar_email_real(email_sindico, assunto, corpo)
        if enviado:
            notify(f"Email enviado para {email_sindico}: {assunto}")
    
    return {"assunto": assunto, "corpo": corpo, "dados": dados, "enviado": bool(email_sindico)}

def run(query: str) -> str:
    result = gerar_email(query)
    msg = f"Email gerado:\n\nAssunto: {result['assunto']}\n\n{result['corpo']}"
    notify(msg[:3000])
    return msg

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Sindico Carlos Condominio Villa Verde portaria virtual"
    print(run(q))
