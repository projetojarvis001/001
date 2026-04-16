#!/usr/bin/env python3
"""
PROATIVO :7793 — JARVIS toma iniciativa propria
Monitora dados e avisa Wagner ANTES de ser perguntado
"""
import sys, os, time, datetime, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Proativo v1")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
VISION = "http://192.168.8.124:5006"
MEMORY = "http://localhost:5010"

alertas_enviados = {}

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def ja_enviou(chave, horas=24):
    """Anti-spam: nao envia mesmo alerta dentro do periodo"""
    ultimo = alertas_enviados.get(chave)
    if not ultimo:
        return False
    diff = (datetime.datetime.now() - ultimo).total_seconds() / 3600
    return diff < horas

def get_briefing():
    try:
        r = requests.get(f"{MEMORY}/briefing", timeout=5)
        return r.json().get("briefing", "")
    except:
        return ""

def analisa_com_jarvis(pergunta: str, contexto: str = "") -> str:
    """Usa o JARVIS para gerar insight proativo"""
    try:
        sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
        from cost_router import ask
        from jarvis_context import SYSTEM_PROMPT_JARVIS

        r_rag = requests.post(f"{VISION}/search",
            json={"query": pergunta, "limit": 3}, timeout=15)
        results = r_rag.json().get("results", [])
        ctx = "\n".join([f"{r.get('title','')}: {r.get('content','')[:200]}" for r in results[:2]])

        prompt = f"{contexto}\n\nKB WPS:\n{ctx}\n\nANALISE PROATIVA: {pergunta}\nSeja direto, use dados reais, max 3 linhas."
        resp = ask(prompt, system=SYSTEM_PROMPT_JARVIS)
        return resp.get("content", "")
    except Exception as e:
        return f"erro: {str(e)[:50]}"

def ciclo_proativo():
    """Roda a cada hora verificando oportunidades de alerta"""
    while True:
        try:
            hora = datetime.datetime.now().hour
            briefing = get_briefing()

            # === ALERTA 1: RELATORIO MATINAL (7h) ===
            if hora == 7 and not ja_enviou("relatorio_matinal", 20):
                insight = analisa_com_jarvis(
                    "quais sao as 3 acoes mais importantes para WPS Digital hoje baseado no pipeline e MRR",
                    briefing
                )
                telegram(f"JARVIS — Bom dia Wagner\n\n{insight}\n\nUse !jarvis para qualquer analise.")
                alertas_enviados["relatorio_matinal"] = datetime.datetime.now()

            # === ALERTA 2: OPORTUNIDADE OUTUBRO/NOVEMBRO (setembro) ===
            mes = datetime.datetime.now().month
            if mes == 9 and not ja_enviou("campanha_outubro", 168):
                insight = analisa_com_jarvis(
                    "prepare resumo da campanha outubro novembro assembleias com meta e acoes imediatas"
                )
                telegram(f"JARVIS — Alerta Estratégico\n\nOUTUBRO está chegando. Pico de assembleias em 30 dias.\n\n{insight}")
                alertas_enviados["campanha_outubro"] = datetime.datetime.now()

            # === ALERTA 3: VISION OFFLINE (qualquer hora) ===
            try:
                r = requests.get(f"{VISION}/health", timeout=5)
                vision_ok = r.status_code == 200
            except:
                vision_ok = False

            if not vision_ok and not ja_enviou("vision_offline", 2):
                telegram("JARVIS ALERTA: VISION offline — RAG e embeddings indisponíveis. Verificar 192.168.8.124")
                alertas_enviados["vision_offline"] = datetime.datetime.now()

            # === ALERTA 4: SHADOW COM NOVA SKILL (qualquer hora) ===
            try:
                r_shadow = requests.get("http://192.168.8.124:5009/stats", timeout=5)
                skills = r_shadow.json().get("skills_criadas", 0)
                ultimo_skills = alertas_enviados.get("ultimo_skills_count", 0)
                if skills > ultimo_skills:
                    ultimas = r_shadow.json().get("ultimas_skills", [])
                    telegram(f"JARVIS aprende: nova skill criada\n\n'{ultimas[0] if ultimas else 'nova skill'}\'\n\nTotal: {skills} skills acumuladas.")
                    alertas_enviados["ultimo_skills_count"] = skills
            except:
                pass

        except Exception as e:
            pass

        time.sleep(3600)  # Verifica a cada hora

@app.get("/")
def root():
    return {"ok": True, "service": "proativo", "alertas_enviados": len(alertas_enviados)}

@app.get("/health")
def health():
    return {"ok": True, "service": "proativo"}

@app.post("/dispara")
def dispara_manual(tipo: str = "matinal"):
    """Dispara alerta manualmente para teste"""
    briefing = get_briefing()
    if tipo == "matinal":
        insight = analisa_com_jarvis("3 acoes prioritarias WPS Digital hoje", briefing)
        telegram(f"JARVIS — Relatorio Manual\n\n{insight}")
        return {"ok": True, "tipo": tipo}
    return {"ok": False, "error": "tipo desconhecido"}

thread = threading.Thread(target=ciclo_proativo, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[Proativo] :7793 — iniciativa propria ativa")
    uvicorn.run(app, host="0.0.0.0", port=7793)
