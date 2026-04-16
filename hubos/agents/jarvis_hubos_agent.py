#!/usr/bin/env python3
"""JARVIS HUBOS :7802"""
import sys, os
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
sys.path.insert(0, "/Users/jarvis001/jarvis/hubos")
import requests
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")
from cost_router import ask
from jarvis_hubos_context import SYSTEM_PROMPT_HUBOS

app = FastAPI(title="JARVIS hubOS v1")
VISION = "http://192.168.8.124:5006"

class TaskRequest(BaseModel):
    task: str

@app.get("/health")
def health():
    return {"ok": True, "service": "jarvis-hubos", "url": "hubos.app"}

@app.post("/")
def handle_task(req: TaskRequest):
    try:
        r = requests.post(f"{VISION}/search",
            json={"query": req.task, "limit": 4}, timeout=15)
        results = r.json().get("results",[])
        ho = [x for x in results if "hubos" in x.get("category","")]
        if not ho: ho = results[:2]
        ctx = "\n".join([f"{x.get('title','')}: {x.get('content','')[:200]}" for x in ho[:3]])
        resp = ask(f"KB hubOS:\n{ctx}\n\nPERGUNTA: {req.task}", system=SYSTEM_PROMPT_HUBOS)
        return {"ok":True,"response":resp.get("content",""),"provider":resp.get("provider",""),"sistema":"hubOS"}
    except Exception as e:
        return {"ok":False,"error":str(e)[:100]}

if __name__ == "__main__":
    print("[JARVIS hubOS] :7802 — online")
    uvicorn.run(app, host="0.0.0.0", port=7802)
