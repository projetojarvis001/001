#!/usr/bin/env python3
"""
JARVIS GRAPE NETWORKS :7800
Instancia separada para Grape Networks — redes corporativas
"""
import sys, os
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")
from cost_router import ask
from jarvis_grape_context import SYSTEM_PROMPT_GRAPE

app = FastAPI(title="JARVIS Grape Networks v1")
VISION = "http://192.168.8.124:5006"

class TaskRequest(BaseModel):
    task: str

@app.get("/health")
def health():
    return {"ok": True, "service": "jarvis-grape", "empresa": "Grape Networks"}

@app.get("/")
def root():
    return {"ok": True, "service": "jarvis-grape",
            "empresa": "Grape Networks",
            "especialidade": "redes corporativas NOC proprio"}

@app.post("/")
def handle_task(req: TaskRequest):
    try:
        r_rag = requests.post(f"{VISION}/search",
            json={"query": req.task, "limit": 4,
                  "filter_category": "grape"}, timeout=15)
        results = r_rag.json().get("results", [])
        # Filtra por grape ou usa todos se nao houver
        grape_results = [r for r in results if "grape" in r.get("category","").lower()]
        if not grape_results:
            grape_results = results[:3]
        ctx = "\n".join([f"{r.get('title','')}: {r.get('content','')[:250]}"
            for r in grape_results[:3]])
        resp = ask(f"KB Grape:\n{ctx}\n\nPERGUNTA: {req.task}",
            system=SYSTEM_PROMPT_GRAPE)
        return {"ok": True, "response": resp.get("content",""),
                "provider": resp.get("provider","groq"),
                "empresa": "Grape Networks"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

if __name__ == "__main__":
    print("[JARVIS Grape] :7800 — Grape Networks online")
    uvicorn.run(app, host="0.0.0.0", port=7800)
