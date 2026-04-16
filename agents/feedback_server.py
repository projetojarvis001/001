#!/usr/bin/env python3
"""
FEEDBACK LOOP :5011 — Wagner avalia respostas do JARVIS
Bom/Errado alimenta o KB automaticamente
"""
import sys, os, json, sqlite3, datetime
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn
import requests
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Feedback Loop v1")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
DB = "/Users/jarvis001/jarvis/data/feedback.db"
VISION = "http://192.168.8.124:5006"

def init_db():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS feedbacks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT,
            pergunta TEXT,
            resposta TEXT,
            avaliacao TEXT,
            correcao TEXT,
            processado INTEGER DEFAULT 0
        )
    """)
    conn.commit()
    conn.close()

init_db()

class FeedbackItem(BaseModel):
    pergunta: str
    resposta: str
    avaliacao: str  # "bom" ou "errado"
    correcao: Optional[str] = ""

class UltimaResposta(BaseModel):
    pergunta: str
    resposta: str

ultima_resposta_cache = {}

@app.get("/health")
def health():
    return {"ok": True, "service": "feedback-loop"}

@app.get("/")
def root():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT avaliacao, COUNT(*) FROM feedbacks GROUP BY avaliacao")
    stats = dict(cur.fetchall())
    cur.execute("SELECT COUNT(*) FROM feedbacks WHERE processado=0")
    pendentes = cur.fetchone()[0]
    conn.close()
    return {"ok": True, "service": "feedback-loop", "stats": stats, "pendentes": pendentes}

@app.post("/ultima")
def salva_ultima(item: UltimaResposta):
    """JARVIS registra sua ultima resposta para feedback posterior"""
    ultima_resposta_cache["pergunta"] = item.pergunta
    ultima_resposta_cache["resposta"] = item.resposta
    ultima_resposta_cache["ts"] = datetime.datetime.now().isoformat()
    return {"ok": True}

@app.post("/avaliar")
def avaliar(item: FeedbackItem):
    """Wagner avalia: bom ou errado"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO feedbacks (ts, pergunta, resposta, avaliacao, correcao)
        VALUES (?, ?, ?, ?, ?)
    """, (datetime.datetime.now().isoformat(),
          item.pergunta, item.resposta, item.avaliacao, item.correcao))
    conn.commit()
    conn.close()

    if item.avaliacao == "bom":
        # Resposta boa vai para o KB como documento de referencia
        try:
            import hashlib
            doc_id = hashlib.md5(f"feedback_{item.pergunta}".encode()).hexdigest()[:12]
            requests.post(f"{VISION}/ingest",
                json={"items": [{"id": doc_id,
                    "title": f"Feedback Bom: {item.pergunta[:60]}",
                    "content": f"PERGUNTA: {item.pergunta} RESPOSTA VALIDADA: {item.resposta}",
                    "category": "feedback_validado"}]},
                timeout=30)
        except: pass
        return {"ok": True, "acao": "resposta boa adicionada ao KB"}

    elif item.avaliacao == "errado" and item.correcao:
        # Correcao vai para o KB com alta prioridade
        try:
            import hashlib
            doc_id = hashlib.md5(f"correcao_{item.pergunta}".encode()).hexdigest()[:12]
            requests.post(f"{VISION}/ingest",
                json={"items": [{"id": doc_id,
                    "title": f"Correcao Wagner: {item.pergunta[:60]}",
                    "content": f"PERGUNTA: {item.pergunta} RESPOSTA CORRETA SEGUNDO WAGNER: {item.correcao} RESPOSTA ERRADA: {item.resposta}",
                    "category": "correcao_wagner"}]},
                timeout=30)
        except: pass
        return {"ok": True, "acao": "correcao adicionada ao KB como prioridade"}

    return {"ok": True, "acao": "feedback registrado"}

@app.get("/telegram/bom")
def feedback_bom_telegram():
    """Endpoint para bot Telegram — Wagner digita !bom"""
    ultima = ultima_resposta_cache.copy()
    if not ultima:
        return {"ok": False, "msg": "nenhuma resposta recente"}
    item = FeedbackItem(
        pergunta=ultima.get("pergunta",""),
        resposta=ultima.get("resposta",""),
        avaliacao="bom"
    )
    return avaliar(item)

@app.get("/telegram/errado")
def feedback_errado_telegram(correcao: str = ""):
    """Endpoint para bot Telegram — Wagner digita !errado [correcao]"""
    ultima = ultima_resposta_cache.copy()
    if not ultima:
        return {"ok": False, "msg": "nenhuma resposta recente"}
    item = FeedbackItem(
        pergunta=ultima.get("pergunta",""),
        resposta=ultima.get("resposta",""),
        avaliacao="errado",
        correcao=correcao
    )
    return avaliar(item)

if __name__ == "__main__":
    print("[Feedback Loop] :5011 — aprendizado ativo")
    uvicorn.run(app, host="0.0.0.0", port=5011)
