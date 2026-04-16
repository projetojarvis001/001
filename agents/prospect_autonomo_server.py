#!/usr/bin/env python3
"""
PROSPECT AUTONOMO :7794
Todo domingo mapeia 10 novos prospects e entrega lista priorizada na segunda 7h
"""
import sys, os, json, datetime, threading, time, hashlib
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Prospect Autonomo v1")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
VISION = "http://192.168.8.124:5006"
MEMORY = "http://localhost:5010"

REGIOES_CAMPINAS = [
    "Alphaville Campinas", "Taquaral Campinas", "Barao Geraldo Campinas",
    "Nova Campinas", "Cambuí Campinas", "Parque Prado Campinas",
    "Bosque Campinas", "Souzas Campinas", "Vinhedo SP",
    "Indaiatuba SP", "Paulinia SP", "Valinhos SP",
    "Ribeirao Preto SP", "Sorocaba SP"
]

PERFIS_ALVO = [
    "condomínio vertical 100 apartamentos",
    "condomínio horizontal fechado",
    "condomínio alto padrao",
    "condomínio com portaria virtual",
    "sindico profissional Campinas"
]

ultimo_prospecting = {}

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def score_prospect(nome: str, regiao: str, unidades: int = 100) -> int:
    score = 0
    if unidades >= 200: score += 10
    elif unidades >= 100: score += 8
    elif unidades >= 60: score += 5
    
    regioes_premium = ["Alphaville", "Nova Campinas", "Cambuí", "Parque Prado", "Ribeirao Preto"]
    if any(r in regiao for r in regioes_premium): score += 8
    else: score += 4
    
    return score

def gerar_prospects_com_jarvis(regiao: str) -> list:
    """Usa JARVIS + KB para gerar prospects realistas da regiao"""
    try:
        sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
        from cost_router import ask
        from jarvis_context import SYSTEM_PROMPT_JARVIS

        r_rag = requests.post(f"{VISION}/search",
            json={"query": f"condomínios {regiao} oportunidade portaria virtual CFTV", "limit": 3},
            timeout=15)
        results = r_rag.json().get("results", [])
        ctx = "\n".join([f"{r.get('title','')}: {r.get('content','')[:200]}" for r in results[:2]])

        prompt = f"""KB WPS:\n{ctx}\n\nGere 3 prospects realistas de condomínios em {regiao} para a WPS Digital.
Para cada um retorne JSON com: nome, unidades (numero), tipo (vertical/horizontal), score_estimado (1-10), abordagem (1 frase).
Responda APENAS com JSON array valido."""

        resp = ask(prompt, system=SYSTEM_PROMPT_JARVIS)
        texto = resp.get("content", "")
        
        import re
        match = re.search(r"\[.*\]", texto, re.DOTALL)
        if match:
            return json.loads(match.group())
    except Exception as e:
        pass
    
    # Fallback: prospects genericos da regiao
    return [
        {"nome": f"Condominio {regiao.split()[0]} Premium", "unidades": 120, "tipo": "vertical",
         "score_estimado": score_prospect("", regiao, 120), "abordagem": f"Sistema CFTV obsoleto em {regiao} — ROI portaria virtual em 12 meses"},
        {"nome": f"Residencial {regiao.split()[0]} Garden", "unidades": 80, "tipo": "vertical",
         "score_estimado": score_prospect("", regiao, 80), "abordagem": f"Sem portaria virtual em {regiao} — economia R$3.700/mes"},
    ]

def ciclo_prospecting():
    while True:
        try:
            agora = datetime.datetime.now()
            dia_semana = agora.weekday()  # 6 = domingo
            hora = agora.hour

            # Domingo: gera prospects
            if dia_semana == 6 and hora == 20:
                chave = f"prospect_{agora.strftime('%Y-%W')}"
                if chave not in ultimo_prospecting:
                    telegram("JARVIS Prospect: Iniciando mapeamento semanal de prospects...")
                    todos_prospects = []
                    
                    for regiao in REGIOES_CAMPINAS[:5]:
                        prospects = gerar_prospects_com_jarvis(regiao)
                        todos_prospects.extend(prospects)
                        time.sleep(2)
                    
                    # Salva prospects
                    os.makedirs("/Users/jarvis001/jarvis/data", exist_ok=True)
                    with open("/Users/jarvis001/jarvis/data/prospects_semana.json", "w") as f:
                        json.dump(todos_prospects, f, ensure_ascii=False, indent=2)
                    
                    ultimo_prospecting[chave] = agora.isoformat()

            # Segunda 7h: entrega lista priorizada
            if dia_semana == 0 and hora == 7:
                chave_entrega = f"entrega_{agora.strftime('%Y-%W')}"
                if chave_entrega not in ultimo_prospecting:
                    try:
                        with open("/Users/jarvis001/jarvis/data/prospects_semana.json") as f:
                            prospects = json.load(f)
                        
                        # Ordena por score
                        prospects_sorted = sorted(prospects,
                            key=lambda x: x.get("score_estimado", 0), reverse=True)[:10]
                        
                        msg = "JARVIS Prospect — Lista Semanal\n\n"
                        for i, p in enumerate(prospects_sorted[:5], 1):
                            msg += f"{i}. {p.get('nome','?')}\n"
                            msg += f"   {p.get('unidades',0)} ap | Score: {p.get('score_estimado',0)}/10\n"
                            msg += f"   Abordagem: {p.get('abordagem','')[:80]}\n\n"
                        
                        msg += "Use !prospect [numero] para ver detalhes e rascunho de abordagem."
                        telegram(msg)
                        ultimo_prospecting[chave_entrega] = agora.isoformat()
                    except:
                        pass

        except Exception as e:
            pass
        
        time.sleep(3600)

@app.get("/health")
def health():
    return {"ok": True, "service": "prospect-autonomo"}

@app.get("/")
def root():
    try:
        with open("/Users/jarvis001/jarvis/data/prospects_semana.json") as f:
            prospects = json.load(f)
        return {"ok": True, "service": "prospect-autonomo", "prospects": len(prospects)}
    except:
        return {"ok": True, "service": "prospect-autonomo", "prospects": 0}

@app.post("/gerar")
def gerar_manual(regiao: str = "Campinas"):
    """Gera prospects manualmente para uma regiao"""
    prospects = gerar_prospects_com_jarvis(regiao)
    
    os.makedirs("/Users/jarvis001/jarvis/data", exist_ok=True)
    arquivo = f"/Users/jarvis001/jarvis/data/prospects_{regiao.replace(' ','_')}.json"
    with open(arquivo, "w") as f:
        json.dump(prospects, f, ensure_ascii=False, indent=2)
    
    # Envia no Telegram
    msg = f"JARVIS Prospect — {regiao}\n\n"
    for p in prospects[:3]:
        msg += f"• {p.get('nome','?')} ({p.get('unidades',0)} ap)\n"
        msg += f"  Score: {p.get('score_estimado',0)}/10\n"
        msg += f"  {p.get('abordagem','')[:80]}\n\n"
    telegram(msg)
    
    return {"ok": True, "prospects": len(prospects), "regiao": regiao}

@app.get("/lista")
def lista_prospects():
    try:
        with open("/Users/jarvis001/jarvis/data/prospects_semana.json") as f:
            prospects = json.load(f)
        return {"ok": True, "prospects": sorted(prospects, key=lambda x: x.get("score_estimado",0), reverse=True)[:10]}
    except:
        return {"ok": True, "prospects": []}

thread = threading.Thread(target=ciclo_prospecting, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[Prospect Autonomo] :7794 — mapeamento semanal ativo")
    uvicorn.run(app, host="0.0.0.0", port=7794)
