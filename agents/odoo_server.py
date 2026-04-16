#!/usr/bin/env python3
"""
ODOO AGENT AUTONOMO :7780
Cria leads, move estagios, registra visitas sem intervencao humana
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

app = FastAPI(title="Odoo Agent Autonomo v2")
ODOO_URL = os.getenv("ODOO_URL", "http://localhost:18070")
ODOO_DB = os.getenv("ODOO_DB", "odoo")
ODOO_USER = os.getenv("ODOO_USER", "wagner@wps.com.br")
ODOO_PASS = os.getenv("ODOO_PASSWORD", "odoowps")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")

pipeline_local = []

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def odoo_rpc(model, method, args=[], kwargs={}):
    try:
        # Autentica
        auth = requests.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc": "2.0", "method": "call", "id": 1,
            "params": {
                "model": "res.users",
                "method": "authenticate",
                "args": [ODOO_DB, ODOO_USER, ODOO_PASS, {}],
                "kwargs": {}
            }
        }, timeout=10)
        uid = auth.json().get("result")
        if not uid:
            return None
        
        r = requests.post(f"{ODOO_URL}/web/dataset/call_kw", json={
            "jsonrpc": "2.0", "method": "call", "id": 2,
            "params": {
                "model": model,
                "method": method,
                "args": [[uid, ODOO_PASS]] + args,
                "kwargs": kwargs
            }
        }, timeout=10)
        return r.json().get("result")
    except Exception as e:
        return None

class LeadRequest(BaseModel):
    nome: str
    condominio: str
    telefone: Optional[str] = ""
    email: Optional[str] = ""
    valor_estimado: Optional[float] = 35000
    origem: Optional[str] = "JARVIS"
    regiao: Optional[str] = "Campinas"

class VisitaRequest(BaseModel):
    lead_id: Optional[int] = 0
    condominio: str
    data: str
    hora: Optional[str] = "09:00"
    tecnico: Optional[str] = "Wagner"

class TaskRequest(BaseModel):
    task: str

@app.get("/health")
def health():
    return {"ok": True, "service": "odoo-agent-v2"}

@app.get("/")
def root():
    return {"ok": True, "service": "odoo-agent-v2",
            "pipeline_local": len(pipeline_local),
            "odoo": ODOO_URL}

@app.post("/criar_lead")
def criar_lead(req: LeadRequest):
    lead = {
        "id": f"L{len(pipeline_local)+1:04d}",
        "nome": req.nome,
        "condominio": req.condominio,
        "telefone": req.telefone,
        "email": req.email,
        "valor": req.valor_estimado,
        "origem": req.origem,
        "regiao": req.regiao,
        "estagio": "lead",
        "created_at": datetime.datetime.now().isoformat()
    }
    pipeline_local.append(lead)
    
    # Salva localmente
    os.makedirs("/Users/jarvis001/jarvis/data", exist_ok=True)
    with open("/Users/jarvis001/jarvis/data/pipeline.json", "w") as f:
        json.dump(pipeline_local, f, ensure_ascii=False, indent=2)
    
    # Tenta criar no Odoo
    result = odoo_rpc("crm.lead", "create", [[{
        "name": f"{req.condominio} — {req.regiao}",
        "contact_name": req.nome,
        "phone": req.telefone,
        "email_from": req.email,
        "expected_revenue": req.valor_estimado,
        "description": f"Lead gerado pelo JARVIS. Origem: {req.origem}"
    }]])
    
    odoo_id = result[0] if result else None
    if odoo_id:
        lead["odoo_id"] = odoo_id
    
    telegram(f"JARVIS Lead: {req.condominio}\nValor: R${req.valor_estimado:,.0f}\nRegiao: {req.regiao}\nID: {lead['id']}")
    return {"ok": True, "lead": lead, "odoo_id": odoo_id}

@app.post("/agendar_visita")
def agendar_visita(req: VisitaRequest):
    visita = {
        "condominio": req.condominio,
        "data": req.data,
        "hora": req.hora,
        "tecnico": req.tecnico,
        "status": "agendada",
        "created_at": datetime.datetime.now().isoformat()
    }
    
    os.makedirs("/Users/jarvis001/jarvis/data", exist_ok=True)
    visitas = []
    if os.path.exists("/Users/jarvis001/jarvis/data/agenda.json"):
        with open("/Users/jarvis001/jarvis/data/agenda.json") as f:
            visitas = json.load(f).get("visitas", [])
    visitas.append(visita)
    with open("/Users/jarvis001/jarvis/data/agenda.json", "w") as f:
        json.dump({"visitas": visitas}, f, ensure_ascii=False, indent=2)
    
    telegram(f"JARVIS Agenda: Visita em {req.condominio}\nData: {req.data} {req.hora}\nTecnico: {req.tecnico}")
    return {"ok": True, "visita": visita}

@app.get("/pipeline")
def ver_pipeline():
    try:
        with open("/Users/jarvis001/jarvis/data/pipeline.json") as f:
            return {"ok": True, "leads": json.load(f)}
    except:
        return {"ok": True, "leads": pipeline_local}

@app.post("/")
def handle_task(req: TaskRequest):
    task = req.task.lower()
    if "pipeline" in task or "leads" in task:
        try:
            with open("/Users/jarvis001/jarvis/data/pipeline.json") as f:
                leads = json.load(f)
            return {"response": f"Pipeline: {len(leads)} leads. Ultimo: {leads[-1]['condominio'] if leads else 'vazio'}"}
        except:
            return {"response": "Pipeline vazio"}
    return {"response": f"Odoo agent ativo. Comandos: criar_lead, agendar_visita, pipeline"}

if __name__ == "__main__":
    print("[Odoo Agent v2] :7780 — loop fechado ativo")
    uvicorn.run(app, host="0.0.0.0", port=7780)
