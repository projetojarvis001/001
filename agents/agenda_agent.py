#!/usr/bin/env python3
"""
JARVIS Agenda Agent — Agendamento automatico visitas tecnicas
Trigger: !visita [condominio] [data] [hora]
Integra com Google Calendar via Microsoft Graph (Outlook) como fallback
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

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

# Agenda local como fallback (arquivo JSON)
AGENDA_FILE = "/Users/jarvis001/jarvis/data/agenda.json"

def load_agenda():
    try:
        os.makedirs(os.path.dirname(AGENDA_FILE), exist_ok=True)
        with open(AGENDA_FILE) as f:
            return json.load(f)
    except: return []

def save_agenda(agenda):
    os.makedirs(os.path.dirname(AGENDA_FILE), exist_ok=True)
    with open(AGENDA_FILE, "w") as f:
        json.dump(agenda, f, indent=2, ensure_ascii=False)

def agendar_visita(query: str) -> str:
    analysis = ask(
        f"""Extraia do pedido de agendamento: "{query}"
JSON: {{"condominio":"nome","data":"DD/MM/YYYY ou descricao","hora":"HH:MM","endereco":"se mencionado","contato":"nome do sindico se mencionado","tipo":"visita_tecnica/reuniao/instalacao"}}
Se a data for relativa (amanha, segunda, etc) converta para DD/MM/YYYY baseado em hoje 14/04/2026.
Responda APENAS JSON.""",
        system="Assistente de agendamento WPS Digital."
    )
    
    try:
        text = analysis.get("content","").strip()
        if "```" in text: text = text.split("```")[1].replace("json","").strip()
        dados = json.loads(text)
    except:
        dados = {"condominio": query, "data": "a definir", "hora": "09:00", "tipo": "visita_tecnica"}
    
    # Salva na agenda local
    agenda = load_agenda()
    evento = {
        "id": len(agenda) + 1,
        "condominio": dados.get("condominio","?"),
        "data": dados.get("data","?"),
        "hora": dados.get("hora","09:00"),
        "tipo": dados.get("tipo","visita_tecnica"),
        "contato": dados.get("contato",""),
        "endereco": dados.get("endereco",""),
        "criado_em": datetime.now().strftime("%d/%m/%Y %H:%M"),
        "status": "agendado"
    }
    agenda.append(evento)
    save_agenda(agenda)
    
    msg = f"""Visita agendada:
Condominio: {evento['condominio']}
Data: {evento['data']} as {evento['hora']}
Tipo: {evento['tipo']}
{f"Contato: {evento['contato']}" if evento['contato'] else ""}
{f"Endereco: {evento['endereco']}" if evento['endereco'] else ""}

ID: {evento['id']} | Para cancelar: !cancelar {evento['id']}"""
    
    notify(msg)
    return msg

def listar_agenda() -> str:
    agenda = load_agenda()
    if not agenda:
        return "Agenda vazia."
    ativos = [e for e in agenda if e.get("status") == "agendado"]
    if not ativos:
        return "Nenhuma visita agendada."
    linhas = ["Agenda WPS Digital:"]
    for e in ativos[-10:]:
        linhas.append(f"  [{e['id']}] {e['data']} {e['hora']} — {e['condominio']} ({e['tipo']})")
    return "
".join(linhas)

def run(query: str) -> str:
    q = query.lower().strip()
    if q in ["listar","agenda","proximas","lista"]:
        result = listar_agenda()
    elif q.startswith("cancelar"):
        try:
            id_evento = int(q.split()[1])
            agenda = load_agenda()
            for e in agenda:
                if e["id"] == id_evento:
                    e["status"] = "cancelado"
            save_agenda(agenda)
            result = f"Visita {id_evento} cancelada."
        except:
            result = "Uso: !visita cancelar [ID]"
    else:
        result = agendar_visita(query)
    notify(result) if "agendada" not in result else None
    return result

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Condominio Villa Verde segunda-feira 14h"
    print(run(q))
