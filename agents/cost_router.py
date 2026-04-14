#!/usr/bin/env python3
import sys, os, warnings, json
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

GROQ_KEY = os.getenv("GROQ_API_KEY","")
ANTHROPIC_KEY = os.getenv("ANTHROPIC_API_KEY","")
GEMINI_KEY = os.getenv("GOOGLE_AI_KEY","")
OLLAMA_URL = "http://192.168.8.124:11434"

def try_groq(messages, system="", max_tokens=1000):
    try:
        from langchain_groq import ChatGroq
        from langchain_core.messages import HumanMessage, SystemMessage
        llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.1)
        msgs = []
        if system: msgs.append(SystemMessage(content=system))
        for m in messages:
            if m["role"]=="user": msgs.append(HumanMessage(content=m["content"]))
            else: msgs.append(SystemMessage(content=m["content"]))
        r = llm.invoke(msgs)
        return {"ok": True, "provider": "groq", "model": "llama-3.3-70b", "content": r.content}
    except Exception as e:
        return {"ok": False, "provider": "groq", "error": str(e)[:100]}

def try_anthropic(messages, system="", max_tokens=1000):
    try:
        import anthropic
        client = anthropic.Anthropic(api_key=ANTHROPIC_KEY)
        r = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=max_tokens,
            system=system or "Voce e o JARVIS, assistente executivo do Wagner Silva, Grupo Wagner.",
            messages=messages
        )
        return {"ok": True, "provider": "anthropic", "model": "claude-sonnet-4", "content": r.content[0].text}
    except Exception as e:
        return {"ok": False, "provider": "anthropic", "error": str(e)[:100]}

def try_gemini(messages, system="", max_tokens=1000):
    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_KEY)
        model = genai.GenerativeModel("gemini-2.0-flash",
            system_instruction=system or "Voce e o JARVIS, assistente executivo do Wagner Silva.")
        prompt = "\n".join([m["content"] for m in messages if m["role"]=="user"])
        r = model.generate_content(prompt)
        return {"ok": True, "provider": "gemini", "model": "gemini-2.0-flash", "content": r.text}
    except Exception as e:
        return {"ok": False, "provider": "gemini", "error": str(e)[:100]}

def try_localai(messages, system="", max_tokens=1000):
    """LocalAI Proxy no VISION — API OpenAI-compatible"""
    try:
        import requests as _req
        msgs = []
        if system: msgs.append({"role": "system", "content": system})
        msgs.extend(messages)
        r = _req.post("http://192.168.8.124:8080/v1/chat/completions",
            json={"model": "local", "messages": msgs, "max_tokens": max_tokens},
            timeout=60)
        if r.status_code == 200:
            text = r.json()["choices"][0]["message"]["content"]
            if text:
                return {"ok": True, "provider": "localai", "model": "qwen3:8b", "content": text}
        return {"ok": False, "provider": "localai", "error": f"status {r.status_code}"}
    except Exception as e:
        return {"ok": False, "provider": "localai", "error": str(e)[:100]}

def try_ollama(messages, system="", max_tokens=1000):
    try:
        import requests
        prompt = "\n".join([m["content"] for m in messages if m["role"]=="user"])
        r = requests.post(f"{OLLAMA_URL}/api/generate",
            json={"model": "qwen2.5:14b", "prompt": prompt, "stream": False}, timeout=60)
        if r.status_code == 200:
            return {"ok": True, "provider": "ollama", "model": "qwen2.5:14b", "content": r.json().get("response","")}
        return {"ok": False, "provider": "ollama", "error": f"status {r.status_code}"}
    except Exception as e:
        return {"ok": False, "provider": "ollama", "error": str(e)[:100]}

def route(messages, system="", max_tokens=1000, prefer_quality=False):
    if prefer_quality:
        chain = [try_anthropic, try_groq, try_gemini, try_localai, try_ollama]
    else:
        chain = [try_groq, try_anthropic, try_gemini, try_localai, try_ollama]
    for fn in chain:
        r = fn(messages, system, max_tokens)
        if r["ok"]:
            print(f"[Router] {r['provider']} ({r['model']})")
            return r
        else:
            print(f"[Router] {r['provider']} falhou: {r['error'][:60]}")
    return {"ok": False, "provider": "none", "content": "Todos os providers falharam."}

def ask(question, system="", prefer_quality=False, max_tokens=1000):
    return route([{"role": "user", "content": question}], system, max_tokens, prefer_quality)

if __name__ == "__main__":
    print("=== COST ROUTER — TESTE ===")
    r = ask("responda apenas: COST ROUTER ONLINE")
    print(f"Resposta: {r['content'][:100]}")
    print(f"Provider: {r['provider']} | Modelo: {r.get('model','?')}")
