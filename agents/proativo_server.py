#!/usr/bin/env python3
"""
PROATIVO V2 :7793
Iniciativa baseada em dados reais — nao apenas por horario
"""
import sys, os, json, datetime, threading, time
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Proativo v2")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
VISION = "http://192.168.8.124:5006"
MEMORY = "http://localhost:5010"
SHADOW = "http://192.168.8.124:5009"
ODOO_AGENT = "http://localhost:7780"

alertas_enviados = {}
estado = {"ultimo_mrr": 0, "ultima_skill": 0, "ultimo_pipeline": 0}

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def ja_enviou(chave, horas=24):
    ultimo = alertas_enviados.get(chave)
    if not ultimo: return False
    return (datetime.datetime.now() - ultimo).total_seconds() / 3600 < horas

def get_briefing():
    try:
        r = requests.get(f"{MEMORY}/briefing", timeout=5)
        return r.json().get("briefing", "")
    except: return ""

def analisa_com_jarvis(pergunta, ctx=""):
    try:
        sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
        from cost_router import ask
        from jarvis_context import SYSTEM_PROMPT_JARVIS
        r_rag = requests.post(f"{VISION}/search",
            json={"query": pergunta, "limit": 3}, timeout=15)
        results = r_rag.json().get("results", [])
        kb = "\n".join([f"{r.get('title','')}: {r.get('content','')[:200]}" for r in results[:2]])
        resp = ask(f"{ctx}\n\nKB:\n{kb}\n\nANALISE: {pergunta}\nMax 4 linhas, numeros reais WPS.",
            system=SYSTEM_PROMPT_JARVIS)
        return resp.get("content", "")
    except Exception as e:
        return f"erro: {str(e)[:50]}"

def verifica_pipeline():
    """Verifica se ha leads novos ou parados no pipeline"""
    try:
        r = requests.get(f"{ODOO_AGENT}/pipeline", timeout=5)
        leads = r.json().get("leads", [])
        total = len(leads)
        if total != estado["ultimo_pipeline"] and total > 0:
            estado["ultimo_pipeline"] = total
            novos = [l for l in leads if l.get("estagio") == "lead"]
            if novos and not ja_enviou("pipeline_update", 4):
                telegram(f"JARVIS Pipeline\n\n{len(novos)} leads novos aguardando acao\nTotal pipeline: {total}\n\nUse !jarvis para ver detalhes")
                alertas_enviados["pipeline_update"] = datetime.datetime.now()
    except: pass

def verifica_shadow_skills():
    """Alerta quando nova skill e criada"""
    try:
        r = requests.get(f"{SHADOW}/stats", timeout=5)
        skills = r.json().get("skills_criadas", 0)
        if skills > estado["ultima_skill"]:
            ultimas = r.json().get("ultimas_skills", [])
            estado["ultima_skill"] = skills
            if not ja_enviou("nova_skill", 12):
                telegram(f"JARVIS aprendeu algo novo\n\nSkill #{skills}: {ultimas[0] if ultimas else 'nova skill'}\n\nTotal de skills acumuladas: {skills}")
                alertas_enviados["nova_skill"] = datetime.datetime.now()
    except: pass

def verifica_intel_mercado():
    """Verifica se ha intel novo no KB e resume"""
    try:
        r = requests.post(f"{VISION}/search",
            json={"query": "intel mercado 2026 novidades portaria virtual", "limit": 3},
            timeout=15)
        results = r.json().get("results", [])
        intel_novo = [x for x in results if "intel_mercado" in x.get("category","")]
        if intel_novo and not ja_enviou("intel_mercado", 24):
            insight = analisa_com_jarvis(
                "quais as principais tendencias do mercado de seguranca condominial baseado nas noticias recentes"
            )
            if insight:
                telegram(f"JARVIS Intel Mercado\n\n{insight}")
                alertas_enviados["intel_mercado"] = datetime.datetime.now()
    except: pass

def ciclo_proativo():
    while True:
        try:
            hora = datetime.datetime.now().hour
            minuto = datetime.datetime.now().minute

            # 7h — relatorio matinal com dados reais
            if hora == 7 and minuto < 5 and not ja_enviou("matinal", 20):
                briefing = get_briefing()
                insight = analisa_com_jarvis(
                    "baseado no contexto atual da WPS Digital: quais as 3 acoes mais urgentes hoje para aumentar MRR e fechar mais contratos",
                    briefing
                )
                telegram(f"JARVIS — Bom dia Wagner\n\n{insight}\n\nUse !status para ver sistema completo")
                alertas_enviados["matinal"] = datetime.datetime.now()

            # A cada ciclo — verifica dados reais
            verifica_pipeline()
            verifica_shadow_skills()

            # 9h — intel mercado
            if hora == 9 and minuto < 5 and not ja_enviou("intel_diario", 20):
                verifica_intel_mercado()
                alertas_enviados["intel_diario"] = datetime.datetime.now()

            # 18h — resumo do dia
            if hora == 18 and minuto < 5 and not ja_enviou("resumo_dia", 20):
                briefing = get_briefing()
                insight = analisa_com_jarvis(
                    "faca um resumo executivo do dia para a WPS Digital: o que foi feito, o que esta pendente, qual a prioridade para amanha",
                    briefing
                )
                telegram(f"JARVIS — Resumo do Dia\n\n{insight}")
                alertas_enviados["resumo_dia"] = datetime.datetime.now()

        except Exception as e:
            pass
        time.sleep(300)  # ciclo a cada 5 minutos

@app.get("/health")
def health():
    return {"ok": True, "service": "proativo-v2"}

@app.get("/")
def root():
    return {"ok": True, "service": "proativo-v2",
            "alertas_enviados": len(alertas_enviados),
            "estado": estado}

@app.post("/dispara")
def dispara(tipo: str = "matinal"):
    briefing = get_briefing()
    if tipo == "matinal":
        insight = analisa_com_jarvis("3 acoes prioritarias WPS hoje para aumentar MRR", briefing)
        telegram(f"JARVIS Manual\n\n{insight}")
        return {"ok": True, "tipo": tipo}
    if tipo == "intel":
        verifica_intel_mercado()
        return {"ok": True, "tipo": tipo}
    if tipo == "pipeline":
        verifica_pipeline()
        return {"ok": True, "tipo": tipo}
    return {"ok": False, "error": "tipo invalido"}

thread = threading.Thread(target=ciclo_proativo, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[Proativo v2] :7793 — iniciativa baseada em dados reais")
    uvicorn.run(app, host="0.0.0.0", port=7793)
