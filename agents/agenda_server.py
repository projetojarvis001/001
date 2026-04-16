#!/usr/bin/env python3
"""
GOOGLE CALENDAR AGENT :7788 v2
Loop fechado de agendamento com Google Calendar real
"""
import sys, os, json, datetime
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Agenda Agent v2")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
GCAL_TOKEN = os.getenv("GOOGLE_CALENDAR_TOKEN","")
GCAL_CALENDAR_ID = os.getenv("GOOGLE_CALENDAR_ID","primary")
AGENDA_FILE = "/Users/jarvis001/jarvis/data/agenda.json"

class VisitaRequest(BaseModel):
    condominio: str
    data: str
    hora: Optional[str] = "09:00"
    sindico: Optional[str] = ""
    telefone: Optional[str] = ""
    descricao: Optional[str] = ""

class TaskRequest(BaseModel):
    task: str

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def salva_agenda_local(visita: dict):
    import os
    os.makedirs(os.path.dirname(AGENDA_FILE), exist_ok=True)
    try:
        with open(AGENDA_FILE) as f:
            agenda = json.load(f)
    except:
        agenda = {"visitas": []}
    agenda["visitas"].append(visita)
    with open(AGENDA_FILE, "w") as f:
        json.dump(agenda, f, ensure_ascii=False, indent=2)

def cria_evento_gcal(visita: dict) -> dict:
    """Cria evento no Google Calendar via API REST"""
    if not GCAL_TOKEN:
        return {"ok": False, "error": "GOOGLE_CALENDAR_TOKEN nao configurado"}
    
    try:
        data = visita.get("data","2026-01-01")
        hora_inicio = visita.get("hora","09:00")
        hora_fim = f"{int(hora_inicio[:2])+1:02d}:{hora_inicio[3:]}"
        
        evento = {
            "summary": f"WPS Visita Tecnica — {visita.get('condominio','')}",
            "description": f"Agendado pelo JARVIS\n\nSindico: {visita.get('sindico','')}\nTelefone: {visita.get('telefone','')}\n{visita.get('descricao','')}",
            "start": {"dateTime": f"{data}T{hora_inicio}:00-03:00", "timeZone": "America/Sao_Paulo"},
            "end": {"dateTime": f"{data}T{hora_fim}:00-03:00", "timeZone": "America/Sao_Paulo"},
            "reminders": {"useDefault": False, "overrides": [
                {"method": "popup", "minutes": 60},
                {"method": "popup", "minutes": 1440}
            ]}
        }
        
        r = requests.post(
            f"https://www.googleapis.com/calendar/v3/calendars/{GCAL_CALENDAR_ID}/events",
            headers={"Authorization": f"Bearer {GCAL_TOKEN}",
                     "Content-Type": "application/json"},
            json=evento, timeout=15
        )
        
        if r.status_code in [200, 201]:
            event_data = r.json()
            return {"ok": True, "event_id": event_data.get("id"), "link": event_data.get("htmlLink","")}
        else:
            return {"ok": False, "error": f"HTTP {r.status_code}: {r.text[:100]}"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

def lista_proximas_gcal(dias: int = 7) -> list:
    """Lista proximos eventos do Google Calendar"""
    if not GCAL_TOKEN:
        return []
    try:
        agora = datetime.datetime.now().isoformat() + "-03:00"
        fim = (datetime.datetime.now() + datetime.timedelta(days=dias)).isoformat() + "-03:00"
        r = requests.get(
            f"https://www.googleapis.com/calendar/v3/calendars/{GCAL_CALENDAR_ID}/events",
            headers={"Authorization": f"Bearer {GCAL_TOKEN}"},
            params={"timeMin": agora, "timeMax": fim, "singleEvents": True,
                    "orderBy": "startTime", "maxResults": 10},
            timeout=10
        )
        if r.status_code == 200:
            return r.json().get("items",[])
    except: pass
    return []

@app.get("/health")
def health():
    gcal_ok = bool(GCAL_TOKEN)
    return {"ok": True, "service": "agenda-v2", "gcal": gcal_ok}

@app.get("/")
def root():
    try:
        with open(AGENDA_FILE) as f:
            agenda = json.load(f)
        visitas = agenda.get("visitas",[])
    except:
        visitas = []
    gcal_proximas = lista_proximas_gcal(7)
    return {"ok": True, "service": "agenda-v2",
            "visitas_locais": len(visitas),
            "gcal_proximas": len(gcal_proximas),
            "gcal_configurado": bool(GCAL_TOKEN)}

@app.post("/agendar")
def agendar(req: VisitaRequest):
    visita = {
        "condominio": req.condominio,
        "data": req.data,
        "hora": req.hora,
        "sindico": req.sindico,
        "telefone": req.telefone,
        "descricao": req.descricao,
        "status": "agendada",
        "created_at": datetime.datetime.now().isoformat()
    }
    
    # Salva local sempre
    salva_agenda_local(visita)
    
    # Tenta Google Calendar
    gcal_result = cria_evento_gcal(visita)
    if gcal_result.get("ok"):
        visita["gcal_id"] = gcal_result.get("event_id")
        visita["gcal_link"] = gcal_result.get("link")
        telegram(f"JARVIS Agenda\nVisita: {req.condominio}\nData: {req.data} {req.hora}\nCalendario: confirmado\n{gcal_result.get('link','')}")
    else:
        telegram(f"JARVIS Agenda\nVisita: {req.condominio}\nData: {req.data} {req.hora}\nCalendario: pendente configuracao OAuth")
    
    return {"ok": True, "visita": visita, "gcal": gcal_result}

@app.get("/proximas")
def proximas(dias: int = 7):
    try:
        with open(AGENDA_FILE) as f:
            agenda = json.load(f)
        visitas = agenda.get("visitas",[])
    except:
        visitas = []
    gcal = lista_proximas_gcal(dias)
    return {"ok": True, "locais": visitas[-5:], "gcal": gcal}

@app.get("/oauth/url")
def oauth_url():
    """Gera URL para autorizar Google Calendar"""
    client_id = os.getenv("GOOGLE_CLIENT_ID","")
    if not client_id:
        return {
            "ok": False,
            "instrucoes": [
                "1. Acesse: https://console.cloud.google.com",
                "2. Crie projeto ou use existente",
                "3. APIs > Google Calendar API > Ativar",
                "4. Credenciais > OAuth 2.0 > Desktop App",
                "5. Baixe o JSON e adicione ao .env:",
                "   GOOGLE_CLIENT_ID=seu_client_id",
                "   GOOGLE_CLIENT_SECRET=seu_client_secret",
                "6. Acesse /oauth/authorize para gerar token"
            ]
        }
    
    scope = "https://www.googleapis.com/auth/calendar"
    redirect = "urn:ietf:wg:oauth:2.0:oob"
    url = (f"https://accounts.google.com/o/oauth2/auth"
           f"?client_id={client_id}&redirect_uri={redirect}"
           f"&scope={scope}&response_type=code&access_type=offline")
    return {"ok": True, "url": url, "instrucao": "Acesse a URL, autorize e cole o codigo em /oauth/token?code=SEU_CODIGO"}

@app.post("/oauth/token")
def oauth_token(code: str):
    """Troca codigo OAuth por token"""
    client_id = os.getenv("GOOGLE_CLIENT_ID","")
    client_secret = os.getenv("GOOGLE_CLIENT_SECRET","")
    if not client_id or not client_secret:
        return {"ok": False, "error": "GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET necessarios"}
    
    try:
        r = requests.post("https://oauth2.googleapis.com/token", data={
            "code": code, "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "grant_type": "authorization_code"
        }, timeout=15)
        data = r.json()
        token = data.get("access_token","")
        refresh = data.get("refresh_token","")
        if token:
            # Salva no .env
            with open("/Users/jarvis001/jarvis/.env","a") as f:
                f.write(f"\nGOOGLE_CALENDAR_TOKEN={token}")
                if refresh:
                    f.write(f"\nGOOGLE_CALENDAR_REFRESH={refresh}")
            return {"ok": True, "msg": "Token salvo. Reinicie o agente agenda."}
        return {"ok": False, "error": data.get("error_description","?")}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@app.post("/")
def handle_task(req: TaskRequest):
    task = req.task.lower()
    if any(w in task for w in ["listar","proximas","agenda","visitas"]):
        try:
            with open(AGENDA_FILE) as f:
                visitas = json.load(f).get("visitas",[])
            if not visitas:
                return {"response": "Agenda vazia. Use /agendar para criar visitas."}
            res = "Proximas visitas:\n"
            for v in visitas[-3:]:
                res += f"  {v.get('data')} {v.get('hora')} — {v.get('condominio')}\n"
            return {"response": res}
        except:
            return {"response": "Agenda vazia."}
    return {"response": f"Agenda agent v2. GCAL: {'configurado' if GCAL_TOKEN else 'pendente OAuth'}"}

if __name__ == "__main__":
    print("[Agenda v2] :7788 — Google Calendar integration")
    uvicorn.run(app, host="0.0.0.0", port=7788)
