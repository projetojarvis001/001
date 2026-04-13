#!/usr/bin/env python3
"""
Agente Outlook JARVIS — lê, organiza e envia emails via Microsoft Graph API
Ativado por: !email ou !outlook no Telegram
"""
import sys, os, warnings, json, requests
warnings.filterwarnings('ignore')
sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')
import msal
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage

load_dotenv('/Users/jarvis001/jarvis/.env')

CLIENT_ID = os.getenv('MS_CLIENT_ID')
TENANT_ID = os.getenv('MS_TENANT_ID')
CLIENT_SECRET = os.getenv('MS_CLIENT_SECRET')
USER_EMAIL = os.getenv('MS_USER_EMAIL')
GROQ_KEY = os.getenv('GROQ_API_KEY')

llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.2)

def get_token():
    app = msal.ConfidentialClientApplication(
        CLIENT_ID,
        authority=f"https://login.microsoftonline.com/{TENANT_ID}",
        client_credential=CLIENT_SECRET
    )
    token = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    return token.get('access_token')

def get_headers():
    return {"Authorization": f"Bearer {get_token()}", "Content-Type": "application/json"}

def list_emails(folder="inbox", top=10) -> list:
    url = f"https://graph.microsoft.com/v1.0/users/{USER_EMAIL}/mailFolders/{folder}/messages"
    params = "$top=" + str(top) + "&$select=subject,from,receivedDateTime,isRead,bodyPreview&$orderby=receivedDateTime desc"
    r = requests.get(f"{url}?{params}", headers=get_headers(), timeout=30)
    return r.json().get('value', []) if r.status_code == 200 else []

def list_contacts(top=50) -> list:
    url = f"https://graph.microsoft.com/v1.0/users/{USER_EMAIL}/contacts"
    params = f"$top={top}&$select=displayName,emailAddresses,companyName"
    r = requests.get(f"{url}?{params}", headers=get_headers(), timeout=30)
    return r.json().get('value', []) if r.status_code == 200 else []

def send_email(to: str, subject: str, body: str) -> bool:
    url = f"https://graph.microsoft.com/v1.0/users/{USER_EMAIL}/sendMail"
    payload = {
        "message": {
            "subject": subject,
            "body": {"contentType": "HTML", "content": body},
            "toRecipients": [{"emailAddress": {"address": to}}]
        },
        "saveToSentItems": True
    }
    r = requests.post(url, headers=get_headers(), json=payload, timeout=30)
    return r.status_code == 202

def run(task: str) -> str:
    print(f"[OutlookAgent] Task: {task[:80]}")
    task_lower = task.lower()

    # Detecta intenção
    if any(w in task_lower for w in ['enviar', 'mandar', 'send', 'escrever email']):
        # Coleta contatos para o LLM decidir destinatário
        contacts = list_contacts(20)
        contact_list = "\n".join([f"- {c.get('displayName','?')}: {c.get('emailAddresses',[{}])[0].get('address','?') if c.get('emailAddresses') else '?'}" for c in contacts[:10]])
        
        response = llm.invoke([
            SystemMessage(content=f"""Você é o agente de email do JARVIS para Wagner Silva (wagner@wps.digital).
Analise o pedido e extraia: destinatário, assunto e corpo do email.
Contatos disponíveis:
{contact_list}

IMPORTANTE: Responda APENAS em JSON:
{{"to": "email@destino.com", "subject": "assunto", "body": "corpo em HTML", "confirm_needed": true}}
confirm_needed deve ser sempre true — Wagner deve confirmar antes de enviar."""),
            HumanMessage(content=task)
        ])
        
        try:
            data = json.loads(response.content.strip().replace('```json','').replace('```',''))
            return f"""📧 *Rascunho de Email*

**Para:** {data.get('to')}
**Assunto:** {data.get('subject')}

**Corpo:**
{data.get('body','')[:500]}

---
Para confirmar o envio, responda: `/confirmar_email`
Para cancelar: `/cancelar_email`"""
        except:
            return response.content

    elif any(w in task_lower for w in ['inbox', 'emails', 'mensagens', 'caixa', 'recebidos']):
        emails = list_emails(top=5)
        if not emails:
            return "❌ Não foi possível acessar os emails."
        
        summary = "\n".join([
            f"{'🔵' if not e.get('isRead') else '⚪'} **{e.get('subject','?')[:50]}**\n   De: {e.get('from',{}).get('emailAddress',{}).get('address','?')}\n   {e.get('bodyPreview','')[:80]}..."
            for e in emails
        ])
        
        response = llm.invoke([
            SystemMessage(content="Você é o assistente de email do JARVIS. Analise os emails e dê um resumo executivo em português para Wagner Silva."),
            HumanMessage(content=f"Emails recentes:\n{summary}\n\nDê um resumo executivo do que precisa de atenção.")
        ])
        
        return f"📬 *Inbox — {len(emails)} emails recentes*\n\n{summary}\n\n---\n🤖 *Análise JARVIS:*\n{response.content[:400]}"

    elif any(w in task_lower for w in ['contatos', 'contacts', 'lista']):
        contacts = list_contacts(20)
        if not contacts:
            return "❌ Não foi possível acessar os contatos."
        lines = [f"- {c.get('displayName','?')} — {c.get('emailAddresses',[{}])[0].get('address','?') if c.get('emailAddresses') else 'sem email'}" for c in contacts[:15]]
        return f"👥 *{len(contacts)} contatos encontrados*\n\n" + "\n".join(lines)

    else:
        # Resposta genérica com contexto de email
        emails = list_emails(top=3)
        email_ctx = "\n".join([f"- {e.get('subject','?')}" for e in emails])
        response = llm.invoke([
            SystemMessage(content=f"Você é o agente de email do JARVIS. Emails recentes na inbox: {email_ctx}"),
            HumanMessage(content=task)
        ])
        return response.content

if __name__ == '__main__':
    task = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else "mostre os emails recentes"
    print(f"\n{'='*60}\nTAREFA: {task}\n{'='*60}")
    print(run(task))
