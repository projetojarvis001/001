#!/usr/bin/env python3
"""Dashboard Server :7900 — serve o HTML sem restricoes CORS"""
import sys, os
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI(title="Dashboard")
app.add_middleware(CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

DASH_FILE = "/Users/jarvis001/jarvis/data/dashboard.html"

@app.get("/", response_class=HTMLResponse)
@app.get("/dashboard", response_class=HTMLResponse)
def dashboard():
    if os.path.exists(DASH_FILE):
        with open(DASH_FILE) as f:
            return HTMLResponse(content=f.read())
    return HTMLResponse("<h1>Dashboard nao encontrado</h1>")

if __name__ == "__main__":
    print("[Dashboard] :7900 — http://localhost:7900")
    uvicorn.run(app, host="0.0.0.0", port=7900)
