#!/usr/bin/env python3
"""JARVIS CRYPTO HUNTER :7799 — Oportunidades cripto sem investimento"""
import sys, os, requests, json, time, datetime, hashlib, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Crypto Hunter v1")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID        = "170323936"
STATE_FILE     = "/Users/jarvis001/jarvis/data/crypto_state.json"

WALLETS = {
    "BTC": "bc1qnn7kz6ps8xz586y8dnqtm7y4d24rvjcz2ar9dc",
    "ETH": "0x306b7e7eB0cC178f9E7315962521958eb23DC0a",
    "ETC": "0x6fbA95c6c4DACBfBC83Ce16D452A2f3837FD93dE",
    "SOL": "5UBZfckYRpTyjiqemY7sysyCXhTMoYSmYDDt61zkf6X",
    "BNB": "0xB879806D640fd508FCac94544c28D22f98266990A",
    "POL": "0x306b7e7eB0cC178f9E7315962521958eb23DC0a",
}

ROI_SCORE = {
    "airdrop_defi": 95, "testnet_reward": 88,
    "ambassador": 75,   "learn_to_earn": 60,
    "bug_bounty": 85,   "nft_free_mint": 50, "faucet": 10,
}

def telegram(msg: str, urgente: bool = False):
    if not TELEGRAM_TOKEN: return
    emoji = "🚀" if urgente else "💰"
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID,
                  "text": f"{emoji} JARVIS Crypto Hunter\n\n{msg}",
                  "parse_mode": "HTML"},
            timeout=10)
    except: pass

def carregar_estado():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as f:
                return json.load(f)
    except: pass
    return {"oportunidades_vistas": {}, "oportunidades_ativas": [],
            "convertidas": [], "ciclos": 0, "ultimo_ciclo": ""}

def salvar_estado(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE,"w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

def buscar_serpapi(query: str, num: int = 5) -> list:
    keys = [os.getenv("SERPAPI_KEY",""), os.getenv("SERPAPI_KEY2","")]
    for key in keys:
        if not key: continue
        try:
            r = requests.get("https://serpapi.com/search", params={
                "q": query, "num": num, "api_key": key, "hl": "pt"
            }, timeout=15)
            if r.status_code == 200:
                results = r.json().get("organic_results",[])
                return [{"title": x.get("title",""),
                         "link": x.get("link",""),
                         "snippet": x.get("snippet","")}
                        for x in results]
        except: continue
    return []

def analisar_llm(titulo: str, snippet: str) -> dict:
    try:
        import importlib, sys
        sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
        cr = importlib.import_module("cost_router")
        ask = cr.ask
        prompt = f"""Analise esta oportunidade cripto. Responda APENAS JSON valido sem markdown:

Titulo: {titulo}
Descricao: {snippet}

{{"tipo":"airdrop_defi|testnet_reward|ambassador|learn_to_earn|faucet|bug_bounty|outro","roi_estimado":"alto|medio|baixo","requer_capital":false,"requer_kyc":false,"dificuldade":"facil|medio|dificil","prazo":"urgente|esta_semana|este_mes|sem_prazo","score":0,"resumo":"uma linha","acao_necessaria":"o que fazer"}}"""
        resp = ask(prompt, system="Especialista cripto. Responda APENAS JSON valido.")
        content = resp.get("content","").strip()
        content = content.replace("```json","").replace("```","").strip()
        # Pega so o JSON
        start = content.find("{")
        end = content.rfind("}") + 1
        if start >= 0 and end > start:
            return json.loads(content[start:end])
    except: pass
    return {"tipo":"outro","roi_estimado":"baixo","requer_capital":True,
            "requer_kyc":False,"dificuldade":"medio","prazo":"sem_prazo",
            "score":10,"resumo":titulo[:80],"acao_necessaria":"verificar manualmente"}

def ciclo_hunter():
    state = carregar_estado()
    state["ciclos"] = state.get("ciclos",0) + 1
    state["ultimo_ciclo"] = datetime.datetime.now().isoformat()
    print(f"\n[Crypto Hunter] Ciclo #{state['ciclos']} — {datetime.datetime.now().strftime('%H:%M')}")

    queries = [
        "airdrop cripto gratuito sem investimento 2026",
        "testnet recompensa token 2026 como participar",
        "ambassador program crypto 2026 ganhar tokens",
        "learn to earn crypto 2026 legítimo",
        "airdrop ethereum layer2 retroativo 2026",
        "solana airdrop 2026 como ganhar gratis",
        "DeFi airdrop criterios elegibilidade 2026",
        "crypto reward program sem deposito 2026",
        "free NFT mint 2026 projetos novos",
        "bug bounty cripto programa recompensa 2026",
    ]

    oportunidades_novas = []

    for query in queries[:4]:
        print(f"  Buscando: {query[:45]}...")
        resultados = buscar_serpapi(query, 3)

        for r in resultados:
            chave = hashlib.md5(r["link"].encode()).hexdigest()[:12]
            if chave in state.get("oportunidades_vistas",{}):
                continue

            analise = analisar_llm(r["title"], r["snippet"])

            if (not analise.get("requer_capital", True) and
                analise.get("score", 0) >= 40):

                op = {
                    "id": chave,
                    "titulo": r["title"],
                    "link": r["link"],
                    "snippet": r["snippet"][:200],
                    "analise": analise,
                    "encontrada_em": datetime.datetime.now().isoformat(),
                    "status": "nova"
                }
                oportunidades_novas.append(op)
                state.setdefault("oportunidades_ativas",[]).append(op)

            state.setdefault("oportunidades_vistas",{})[chave] = {
                "titulo": r["title"][:60],
                "visto_em": datetime.datetime.now().isoformat()
            }
        time.sleep(2)

    if oportunidades_novas:
        oportunidades_novas.sort(
            key=lambda x: x["analise"].get("score",0), reverse=True)

        for op in oportunidades_novas[:3]:
            a = op["analise"]
            score = a.get("score",0)
            emoji = "🔥" if score >= 80 else "⭐" if score >= 60 else "💡"
            msg = (f"{emoji} <b>OPORTUNIDADE</b>\n\n"
                   f"<b>{op['titulo'][:60]}</b>\n\n"
                   f"📊 Tipo: {a.get('tipo','?')}\n"
                   f"💰 ROI: {a.get('roi_estimado','?')} (score {score}/100)\n"
                   f"⚡ Prazo: {a.get('prazo','?')}\n"
                   f"🎯 Dificuldade: {a.get('dificuldade','?')}\n\n"
                   f"📝 {a.get('resumo','')}\n\n"
                   f"✅ <b>Ação:</b> {a.get('acao_necessaria','')[:100]}\n\n"
                   f"🔗 {op['link'][:80]}")
            telegram(msg, urgente=(score >= 80))

        print(f"  {len(oportunidades_novas)} oportunidades novas")
    else:
        print(f"  Nenhuma nova oportunidade neste ciclo")

    # Limpa estado
    cutoff = (datetime.datetime.now() - datetime.timedelta(days=30)).isoformat()
    state["oportunidades_ativas"] = [
        op for op in state.get("oportunidades_ativas",[])
        if op.get("encontrada_em","") > cutoff
    ]
    if len(state.get("oportunidades_vistas",{})) > 2000:
        items = sorted(state["oportunidades_vistas"].items(),
                       key=lambda x: x[1].get("visto_em",""))
        state["oportunidades_vistas"] = dict(items[-1000:])

    salvar_estado(state)
    return oportunidades_novas

@app.get("/")
def status():
    state = carregar_estado()
    ativas = state.get("oportunidades_ativas",[])
    top = sorted(ativas, key=lambda x: x.get("analise",{}).get("score",0),
                 reverse=True)[:5]
    return {"ok": True, "service": "crypto-hunter",
            "ciclos": state.get("ciclos",0),
            "ultimo_ciclo": state.get("ultimo_ciclo","nunca"),
            "oportunidades_ativas": len(ativas),
            "wallets": list(WALLETS.keys()),
            "top5": [{"titulo": o["titulo"][:50],
                      "score": o.get("analise",{}).get("score",0),
                      "tipo": o.get("analise",{}).get("tipo","?")}
                     for o in top]}

@app.get("/scan")
def scan_manual():
    ops = ciclo_hunter()
    return {"ok": True, "novas": len(ops), "oportunidades": ops[:10]}

@app.get("/top")
def top_oportunidades():
    state = carregar_estado()
    ativas = state.get("oportunidades_ativas",[])
    top = sorted(ativas, key=lambda x: x.get("analise",{}).get("score",0),
                 reverse=True)[:20]
    return {"ok": True, "total": len(ativas), "top20": top}

@app.get("/saldos")
def verificar_saldos():
    """Verifica saldos via APIs publicas"""
    saldos = {}
    try:
        r = requests.get(
            f"https://blockchain.info/rawaddr/{WALLETS['BTC']}?limit=1",
            timeout=10)
        saldos["BTC"] = r.json().get("final_balance",0) / 1e8
    except: saldos["BTC"] = "erro"
    try:
        r = requests.get(
            f"https://api.etherscan.io/api?module=account&action=balance&address={WALLETS['ETH']}&tag=latest",
            timeout=10)
        saldos["ETH"] = int(r.json().get("result","0")) / 1e18
    except: saldos["ETH"] = "erro"
    return {"ok": True, "saldos": saldos, "wallets": WALLETS}

@app.post("/marcar_convertida")
def marcar_convertida(data: dict):
    state = carregar_estado()
    op_id = data.get("id","")
    for op in state.get("oportunidades_ativas",[]):
        if op.get("id") == op_id:
            op["status"] = "convertida"
            op["valor_brl"] = data.get("valor_brl",0)
            op["convertida_em"] = datetime.datetime.now().isoformat()
            state.setdefault("convertidas",[]).append(op)
            tipo = op.get("analise",{}).get("tipo","outro")
            if tipo in ROI_SCORE:
                ROI_SCORE[tipo] = min(100, ROI_SCORE[tipo] + 5)
            salvar_estado(state)
            return {"ok": True}
    return {"ok": False, "error": "nao encontrada"}

def loop_background():
    def run():
        time.sleep(60)
        while True:
            try: ciclo_hunter()
            except Exception as e: print(f"[Crypto Hunter] Erro: {e}")
            time.sleep(7200)  # 2 horas
    threading.Thread(target=run, daemon=True).start()
    print("[Crypto Hunter] Loop 2h iniciado")

if __name__ == "__main__":
    print("[JARVIS Crypto Hunter] :7799 iniciando...")
    print(f"Wallets: {list(WALLETS.keys())}")
    loop_background()
    uvicorn.run(app, host="0.0.0.0", port=7799)
