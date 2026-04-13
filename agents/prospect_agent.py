#!/usr/bin/env python3
import sys, os, warnings, json, requests
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

try:
    from cost_router import ask
except:
    from langchain_groq import ChatGroq
    from langchain_core.messages import HumanMessage
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0)
    def ask(q, system="", **kwargs):
        return {"ok": True, "content": _llm.invoke([HumanMessage(content=q)]).content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

KEYWORDS = [
    "portaria virtual condominio campinas",
    "cftv condominio sp instalacao",
    "camera seguranca condominio campinas",
    "controle acesso condominio sao paulo",
]

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def busca_duckduckgo(keyword):
    try:
        r = requests.get("https://api.duckduckgo.com/",
            params={"q": keyword, "format": "json", "no_html": 1},
            timeout=15, headers={"User-Agent": "JARVIS/1.0"})
        if r.status_code == 200:
            data = r.json()
            results = []
            if data.get("Abstract"):
                results.append({"title": data.get("Heading",""), "snippet": data.get("Abstract","")})
            for topic in data.get("RelatedTopics", [])[:3]:
                if isinstance(topic, dict) and topic.get("Text"):
                    results.append({"title": topic.get("Text","")[:80], "snippet": topic.get("Text","")})
            return results
    except: pass
    return []

def qualifica(keyword, results):
    if not results:
        return None
    snippets = chr(10).join([f"- {r.get('snippet','')[:100]}" for r in results[:3]])
    resp = ask(
        f"""Keyword: "{keyword}"
Resultados: {snippets}

JSON apenas: {{"score":1-10,"e_lead":true/false,"resumo":"1 linha","proximo_passo":"acao"}}""",
        system="Especialista vendas B2B condomínios. Seja direto."
    )
    try:
        text = resp.get("content","").strip()
        if "```" in text: text = text.split("```")[1].replace("json","").strip()
        return json.loads(text)
    except: return None

def run(keyword=None):
    kws = [keyword] if keyword else KEYWORDS[:2]
    notify(f"Prospeccao: {len(kws)} keywords")
    leads = []
    for kw in kws:
        results = busca_duckduckgo(kw)
        q = qualifica(kw, results)
        if q and q.get("e_lead") and q.get("score",0) >= 6:
            leads.append(q)
            emoji = "🔥" if q.get("score",0) >= 8 else "⭐"
            notify(f"{emoji} *LEAD {q.get('score')}/10*\n{q.get('resumo','')}\nProximo: {q.get('proximo_passo','')}")
    if not leads:
        notify("Prospeccao: nenhum lead qualificado")
    return leads

if __name__ == "__main__":
    r = run(" ".join(sys.argv[1:]) if len(sys.argv)>1 else None)
    print(f"Leads: {len(r)}")
