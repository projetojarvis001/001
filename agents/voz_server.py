#!/usr/bin/env python3
"""
VOZ AGENT :5013 — Speech-to-Text + Text-to-Speech
Whisper para STT, macOS say para TTS imediato
Qwen3-TTS quando disponivel no Friday
"""
import sys, os, subprocess, tempfile
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Voz Agent v1")

class TextRequest(BaseModel):
    text: str
    voice: str = "Luciana"  # Voz PT-BR do macOS

@app.get("/health")
def health():
    return {"ok": True, "service": "voz-agent", "tts": "macos-say", "stt": "whisper"}

@app.post("/falar")
def falar(req: TextRequest):
    """Converte texto em fala usando vozes nativas do macOS"""
    try:
        # macOS say com voz Luciana (PT-BR)
        subprocess.run(
            ["say", "-v", req.voice, req.text],
            timeout=30, capture_output=True
        )
        return {"ok": True, "text": req.text[:50], "voice": req.voice}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

@app.post("/falar_arquivo")
def falar_arquivo(req: TextRequest):
    """Converte texto em arquivo de audio"""
    try:
        output = f"/tmp/jarvis_speech_{os.getpid()}.aiff"
        subprocess.run(
            ["say", "-v", req.voice, "-o", output, req.text],
            timeout=30, capture_output=True
        )
        return {"ok": True, "arquivo": output, "voice": req.voice}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

@app.post("/transcrever")
async def transcrever(audio: UploadFile = File(...)):
    """Converte audio em texto usando Whisper"""
    try:
        import whisper
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(await audio.read())
            tmp_path = f.name
        model = whisper.load_model("base")
        result = model.transcribe(tmp_path, language="pt")
        os.unlink(tmp_path)
        return {"ok": True, "texto": result["text"], "idioma": result.get("language","pt")}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

@app.get("/vozes")
def listar_vozes():
    """Lista vozes PT-BR disponiveis no macOS"""
    r = subprocess.run(["say", "-v", "?"], capture_output=True, text=True)
    vozes_pt = [l for l in r.stdout.split("\n") if "pt" in l.lower() or "brazil" in l.lower()]
    return {"ok": True, "vozes_pt": vozes_pt}

@app.post("/jarvis_fala")
def jarvis_fala(req: TextRequest):
    """JARVIS responde em voz alta — integra com o agente principal"""
    try:
        # Remove markdown e caracteres especiais
        import re
        texto_limpo = re.sub(r"[*#_`]", "", req.text)
        texto_limpo = re.sub(r"\n+", ". ", texto_limpo)
        texto_limpo = texto_limpo[:500]  # Limita tamanho
        subprocess.Popen(["say", "-v", "Luciana", texto_limpo])
        return {"ok": True, "falando": texto_limpo[:80]}
    except Exception as e:
        return {"ok": False, "error": str(e)[:100]}

if __name__ == "__main__":
    print("[Voz Agent] :5013 — TTS/STT ativo")
    print("Vozes PT-BR: Luciana, Joana")
    uvicorn.run(app, host="0.0.0.0", port=5013)
