#!/usr/bin/env python3
"""JARVIS INTEGRACONDO :7801"""
import sys, os
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
sys.path.insert(0, "/Users/jarvis001/jarvis/integracondo")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")
from cost_router import ask
from jarvis_integracondo_context import SYSTEM_PROMPT_INTEGRACONDO

app = FastAPI(title="JARVIS Integracondo v1")
VISION = "http://192.168.8.124:5006"

class TaskRequest(BaseModel):
    task: str

@app.get("/health")
def health():
    return {"ok": True, "service": "jarvis-integracondo"}

@app.get("/")
def root():
    return {"ok": True, "service": "jarvis-integracondo", "foco": "podcast comunidade condominial"}

@app.post("/")
def handle_task(req: TaskRequest):
    try:
        r_rag = requests.post(f"{VISION}/search",
            json={"query": req.task, "limit": 4}, timeout=15)
        results = r_rag.json().get("results", [])
        ic_results = [r for r in results if "integracondo" in r.get("category","").lower()]
        if not ic_results: ic_results = results[:3]
        ctx = "\n".join([f"{r.get('title','')}: {r.get('content','')[:250]}" for r in ic_results[:3]])
        resp = ask(f"KB Integracondo:\n{ctx}\n\nPERGUNTA: {req.task}", system=SYSTEM_PROMPT_INTEGRACONDO)
        return {"ok": True, "response": resp.get("content",""), "provider": resp.get("provider","groq"), "empresa": "Integracondo"}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

if __name__ == "__main__":
    print("[JARVIS Integracondo] :7801 — online")
    uvicorn.run(app, host="0.0.0.0", port=7801)
