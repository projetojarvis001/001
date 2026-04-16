#!/usr/bin/env python3
"""
MEMORIA API :5010 — Contexto persistente do Wagner/JARVIS
"""
import sys, os, sqlite3, datetime
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn

app = FastAPI(title="Memory API v1")
DB = "/Users/jarvis001/jarvis/data/wagner_memory.db"

class MemoriaItem(BaseModel):
    tipo: str
    conteudo: str
    relevancia: Optional[int] = 5

class ContextoItem(BaseModel):
    chave: str
    valor: str

@app.get("/")
def root():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM memoria_curta")
    mc = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM memoria_longa")
    ml = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM contexto_wagner")
    ctx = cur.fetchone()[0]
    conn.close()
    return {"ok": True, "service": "memory-api",
            "memoria_curta": mc, "memoria_longa": ml, "contexto": ctx}

@app.get("/health")
def health():
    return {"ok": True, "service": "memory-api"}

@app.get("/contexto")
def get_contexto():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT chave, valor, updated_at FROM contexto_wagner ORDER BY chave")
    rows = cur.fetchall()
    conn.close()
    return {"contexto": {r[0]: {"valor": r[1], "updated": r[2]} for r in rows}}

@app.post("/contexto")
def set_contexto(item: ContextoItem):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        INSERT OR REPLACE INTO contexto_wagner (chave, valor, updated_at)
        VALUES (?, ?, ?)
    """, (item.chave, item.valor, datetime.datetime.now().isoformat()))
    conn.commit()
    conn.close()
    return {"ok": True, "chave": item.chave}

@app.post("/lembrar")
def lembrar(item: MemoriaItem):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO memoria_curta (ts, tipo, conteudo, relevancia)
        VALUES (?, ?, ?, ?)
    """, (datetime.datetime.now().isoformat(), item.tipo, item.conteudo, item.relevancia))
    conn.commit()
    conn.close()
    return {"ok": True}

@app.get("/recall")
def recall(query: str = "", limit: int = 10):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    if query:
        cur.execute("""
            SELECT ts, tipo, conteudo, relevancia FROM memoria_curta
            WHERE conteudo LIKE ? ORDER BY relevancia DESC, ts DESC LIMIT ?
        """, (f"%{query}%", limit))
    else:
        cur.execute("""
            SELECT ts, tipo, conteudo, relevancia FROM memoria_curta
            ORDER BY ts DESC LIMIT ?
        """, (limit,))
    rows = cur.fetchall()
    conn.close()
    return {"memorias": [{"ts": r[0][:16], "tipo": r[1], "conteudo": r[2], "relevancia": r[3]} for r in rows]}

@app.get("/briefing")
def briefing():
    """Contexto completo para injetar no JARVIS antes de cada resposta"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT chave, valor FROM contexto_wagner ORDER BY chave")
    ctx = dict(cur.fetchall())
    cur.execute("""
        SELECT tipo, conteudo FROM memoria_curta
        ORDER BY relevancia DESC, ts DESC LIMIT 5
    """)
    recentes = cur.fetchall()
    conn.close()

    briefing_text = f"""CONTEXTO WAGNER SILVA:
Nome: {ctx.get("nome","Wagner")} — {ctx.get("cargo","Chairman")}
Empresa: {ctx.get("empresa_principal","")}
MRR: {ctx.get("mrr_atual","")} meta {ctx.get("meta_mrr","")}
Contratos: {ctx.get("contratos_ativos","")} ativos | NPS {ctx.get("nps_atual","")} meta {ctx.get("meta_nps","")}
Prioridades: {ctx.get("prioridade_2026","")}
Ultimo assunto: {ctx.get("ultimo_assunto","")}"""

    if recentes:
        briefing_text += "

MEMORIAS RECENTES:"
        for tipo, conteudo in recentes[:3]:
            briefing_text += f"
- [{tipo}] {conteudo[:100]}"

    return {"briefing": briefing_text, "contexto": ctx}

if __name__ == "__main__":
    print("[Memory API] :5010 — contexto Wagner ativo")
    uvicorn.run(app, host="0.0.0.0", port=5010)
