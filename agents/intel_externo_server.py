#!/usr/bin/env python3
"""
INTEL EXTERNO :7795
Monitora noticias, LinkedIn concorrentes, licitacoes Campinas
Usa SerpAPI para busca real
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

app = FastAPI(title="Intel Externo v1")
SERPAPI_KEY = os.getenv("SERPAPI_KEY", "")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
VISION = "http://192.168.8.124:5006"

cache_intel = {}

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def serpapi_search(query: str, num: int = 5) -> list:
    if not SERPAPI_KEY or SERPAPI_KEY == "":
        # Fallback sem SerpAPI — usa DuckDuckGo simples
        try:
            r = requests.get(
                f"https://api.duckduckgo.com/?q={query}&format=json&no_html=1&no_redirect=1",
                timeout=10, headers={"User-Agent": "JARVIS/1.0"}
            )
            data = r.json()
            results = []
            for topic in data.get("RelatedTopics", [])[:num]:
                if isinstance(topic, dict) and topic.get("Text"):
                    results.append({"title": topic.get("Text","")[:100], "snippet": topic.get("Text","")[:200], "link": topic.get("FirstURL","")})
            return results
        except:
            return []
    
    try:
        r = requests.get("https://serpapi.com/search", params={
            "q": query, "api_key": SERPAPI_KEY,
            "num": num, "hl": "pt", "gl": "br"
        }, timeout=15)
        results = r.json().get("organic_results", [])
        return [{"title": r.get("title",""), "snippet": r.get("snippet",""), "link": r.get("link","")} for r in results[:num]]
    except:
        return []

def monitorar_mercado():
    queries = [
        "portaria virtual condominio Campinas 2026",
        "seguranca eletronica condominio SP novidades",
        "licitacao seguranca publica Campinas",
        "Techsec seguranca condominio",
        "sindico profissional Campinas segurança",
    ]
    
    todos_resultados = []
    for query in queries:
        results = serpapi_search(query, 3)
        todos_resultados.extend(results)
        time.sleep(1)
    
    return todos_resultados

def ciclo_intel():
    while True:
        try:
            hora = datetime.datetime.now().hour
            # Monitora diariamente as 9h
            if hora == 9:
                chave = f"intel_{datetime.date.today().isoformat()}"
                if chave not in cache_intel:
                    resultados = monitorar_mercado()
                    cache_intel[chave] = resultados
                    
                    if resultados:
                        # Ingere no KB para o JARVIS ter acesso
                        import hashlib
                        docs = []
                        for r in resultados[:5]:
                            doc_id = hashlib.md5(r.get("link","").encode()).hexdigest()[:12]
                            docs.append({
                                "id": doc_id,
                                "title": f"Intel: {r.get('title','')[:60]}",
                                "content": r.get("snippet",""),
                                "category": "intel_mercado"
                            })
                        
                        requests.post(f"{VISION}/ingest",
                            json={"items": docs}, timeout=30)
                        
                        msg = "JARVIS Intel — Mercado hoje\n\n"
                        for r in resultados[:3]:
                            msg += f"• {r.get('title','')[:60]}\n"
                        telegram(msg)
        except: pass
        time.sleep(3600)

@app.get("/health")
def health():
    return {"ok": True, "service": "intel-externo"}

@app.get("/")
def root():
    return {"ok": True, "service": "intel-externo", "serpapi": bool(SERPAPI_KEY), "cache": len(cache_intel)}

@app.post("/buscar")
def buscar(query: str, ingerir: bool = True):
    results = serpapi_search(query, 5)
    
    if ingerir and results:
        import hashlib
        docs = [{"id": hashlib.md5(r.get("link","").encode()).hexdigest()[:12],
                 "title": f"Intel: {r.get('title','')[:60]}",
                 "content": r.get("snippet",""),
                 "category": "intel_busca"} for r in results]
        try:
            requests.post(f"{VISION}/ingest", json={"items": docs}, timeout=30)
        except: pass
    
    return {"ok": True, "query": query, "results": results, "ingerido": ingerir}

@app.get("/mercado")
def intel_mercado():
    resultados = monitorar_mercado()
    return {"ok": True, "resultados": resultados}

thread = threading.Thread(target=ciclo_intel, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[Intel Externo] :7795 — monitorando mercado")
    uvicorn.run(app, host="0.0.0.0", port=7795)
