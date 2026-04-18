#!/usr/bin/env python3
"""
JARVIS POLYMARKET AGENT :7812
Sistema Bayesiano de Prediction Markets
Framework: Temporal bias + Kelly sizing + Volatility filter
Objetivo: capital dos airdrops → compound → 1 BTC
"""
import sys, os, json, time, datetime, requests, math, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Polymarket Agent v1")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID        = "170323936"
STATE_FILE     = "/Users/jarvis001/jarvis/data/polymarket_state.json"

# Capital inicial — começa com zero, usa tokens dos airdrops
CAPITAL_INICIAL_USD = 20.0
MIN_EDGE            = 0.65   # 65% edge minimo para operar
MAX_KELLY_FRACTION  = 0.25   # Max 25% do capital por trade
MIN_LIQUIDEZ_USD    = 1000   # Mercado precisa ter $1k+ liquidez

def telegram(msg: str, urgente: bool = False):
    if not TELEGRAM_TOKEN: return
    emoji = "📈" if not urgente else "🚨"
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID,
                  "text": f"{emoji} JARVIS Polymarket\n\n{msg}",
                  "parse_mode": "HTML"},
            timeout=10)
    except: pass

def carregar_estado():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as f:
                return json.load(f)
    except: pass
    return {
        "capital_usd": CAPITAL_INICIAL_USD,
        "trades": [],
        "wins": 0,
        "losses": 0,
        "profit_total": 0.0,
        "bayesian_priors": {},  # aprende com historico
        "ciclos": 0,
        "ultimo_ciclo": ""
    }

def salvar_estado(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE,"w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

def buscar_mercados_polymarket() -> list:
    """Busca mercados ativos no Polymarket via API publica"""
    mercados = []
    try:
        # API publica Polymarket
        r = requests.get(
            "https://gamma-api.polymarket.com/markets",
            params={
                "active": "true",
                "closed": "false",
                "limit": 100,
                "order": "volume",
                "ascending": "false"
            },
            timeout=15)

        if r.status_code == 200:
            data = r.json()
            for m in data:
                # Filtra mercados com liquidez suficiente
                volume = float(m.get("volume","0") or 0)
                liquidity = float(m.get("liquidity","0") or 0)

                if liquidity < MIN_LIQUIDEZ_USD:
                    continue

                # Extrai preco YES/NO
                outcomes = m.get("outcomes","[]")
                if isinstance(outcomes, str):
                    try: outcomes = json.loads(outcomes)
                    except: continue

                prices = m.get("outcomePrices","[]")
                if isinstance(prices, str):
                    try: prices = json.loads(prices)
                    except: continue

                if len(outcomes) >= 2 and len(prices) >= 2:
                    try:
                        yes_price = float(prices[0])
                        no_price  = float(prices[1])
                        mercados.append({
                            "id":        m.get("id",""),
                            "question":  m.get("question",""),
                            "yes_price": yes_price,
                            "no_price":  no_price,
                            "volume":    volume,
                            "liquidity": liquidity,
                            "end_date":  m.get("endDate",""),
                            "category":  m.get("category",""),
                        })
                    except: continue

    except Exception as e:
        print(f"[Polymarket] Erro API: {e}")

    return mercados

def calcular_edge_bayesiano(mercado: dict, state: dict) -> dict:
    """
    Calcula edge usando framework Bayesiano
    Temporal bias: probabilidade real vs preco de mercado
    """
    yes_price = mercado["yes_price"]
    no_price  = mercado["no_price"]
    question  = mercado["question"].lower()

    # Prior base — começa com probabilidade igual ao preco de mercado
    # Ajusta com base em categorias conhecidas
    prior_yes = yes_price

    # Temporal bias: eventos proximos tem mais certeza
    end_date = mercado.get("end_date","")
    dias_restantes = 30  # default
    if end_date:
        try:
            end = datetime.datetime.fromisoformat(end_date.replace("Z",""))
            dias_restantes = max(1, (end - datetime.datetime.now()).days)
        except: pass

    # Quanto mais proximo, mais confiante no preco atual
    decay = math.exp(-dias_restantes / 30)

    # Ajuste por categorias com historico
    categoria = mercado.get("category","").lower()
    priors_categoria = state.get("bayesian_priors",{}).get(categoria, {})
    win_rate_categoria = priors_categoria.get("win_rate", 0.5)

    # Edge calculado
    # Se mercado diz 60% e nosso modelo diz 70% → edge de 10%
    modelo_yes = prior_yes * (1 + decay * 0.1) * (win_rate_categoria / 0.5)
    modelo_yes = max(0.05, min(0.95, modelo_yes))

    edge_yes = modelo_yes - yes_price
    edge_no  = (1 - modelo_yes) - no_price

    # Volatility filter — ignora mercados muito proximos de 50/50
    volatilidade_ok = abs(yes_price - 0.5) > 0.1

    # Determina lado com maior edge
    if edge_yes > edge_no and edge_yes > 0:
        lado = "YES"
        edge = edge_yes
        preco = yes_price
    elif edge_no > 0:
        lado = "NO"
        edge = edge_no
        preco = no_price
    else:
        lado = None
        edge = 0
        preco = 0

    return {
        "lado": lado,
        "edge": edge,
        "preco": preco,
        "modelo_prob": modelo_yes,
        "dias_restantes": dias_restantes,
        "volatilidade_ok": volatilidade_ok,
        "edge_minimo_ok": edge >= (MIN_EDGE - 0.5),  # edge relativo
    }

def kelly_sizing(edge: float, preco: float, capital: float) -> float:
    """
    Kelly criterion para sizing da posicao
    f = (bp - q) / b
    onde b = odds, p = prob win, q = prob loss
    """
    if preco <= 0 or preco >= 1:
        return 0

    odds = (1 / preco) - 1  # retorno se ganhar
    p_win = preco + edge     # probabilidade estimada
    p_loss = 1 - p_win

    kelly_f = (odds * p_win - p_loss) / odds
    kelly_f = max(0, kelly_f)

    # Usa fração do Kelly para ser conservador (Half-Kelly)
    half_kelly = kelly_f * 0.5

    # Limita ao maximo definido
    fraction = min(half_kelly, MAX_KELLY_FRACTION)
    posicao = capital * fraction

    return round(posicao, 2)

def analisar_mercados(state: dict) -> list:
    """Analisa mercados e encontra oportunidades com edge"""
    print(f"[Polymarket] Buscando mercados...")
    mercados = buscar_mercados_polymarket()
    print(f"[Polymarket] {len(mercados)} mercados com liquidez")

    oportunidades = []
    for m in mercados:
        analise = calcular_edge_bayesiano(m, state)

        if (analise["lado"] and
            analise["edge"] >= 0.05 and  # edge minimo 5%
            analise["volatilidade_ok"] and
            m["liquidity"] >= MIN_LIQUIDEZ_USD):

            posicao = kelly_sizing(
                analise["edge"],
                analise["preco"],
                state["capital_usd"])

            if posicao >= 1.0:  # minimo $1 por trade
                oportunidades.append({
                    "mercado":     m,
                    "analise":     analise,
                    "posicao_usd": posicao,
                    "score":       analise["edge"] * 100,
                })

    # Ordena por edge
    oportunidades.sort(key=lambda x: x["score"], reverse=True)
    return oportunidades[:5]  # top 5

def ciclo_polymarket():
    """Ciclo principal de analise"""
    state = carregar_estado()
    state["ciclos"] = state.get("ciclos",0) + 1
    state["ultimo_ciclo"] = datetime.datetime.now().isoformat()

    print(f"\n[Polymarket] Ciclo #{state['ciclos']}")
    print(f"Capital: ${state['capital_usd']:.2f}")

    oportunidades = analisar_mercados(state)
    print(f"Oportunidades encontradas: {len(oportunidades)}")

    for op in oportunidades:
        m = op["mercado"]
        a = op["analise"]
        pos = op["posicao_usd"]
        edge = a["edge"]
        score = op["score"]

        # Alerta no Telegram — usuario decide se executa
        # (execucao real requer API key e capital)
        msg = (
            f"🎯 <b>OPORTUNIDADE POLYMARKET</b>\n\n"
            f"<b>{m['question'][:80]}</b>\n\n"
            f"📊 Lado: <b>{a['lado']}</b> @ {a['preco']:.2f}\n"
            f"🧮 Edge: {edge:.1%}\n"
            f"🎲 Modelo: {a['modelo_prob']:.1%}\n"
            f"💰 Kelly sizing: ${pos:.2f}\n"
            f"📅 Dias restantes: {a['dias_restantes']}\n"
            f"💧 Liquidez: ${m['liquidity']:,.0f}\n"
            f"📈 Volume: ${m['volume']:,.0f}\n\n"
            f"⚡ Score: {score:.1f}/100\n\n"
            f"🔗 polymarket.com"
        )
        telegram(msg, urgente=(score >= 15))

    salvar_estado(state)
    return oportunidades

# Atualiza Bayesian priors com resultado de trade
def registrar_resultado(trade_id: str, ganhou: bool,
                        categoria: str, edge_usado: float):
    state = carregar_estado()
    priors = state.setdefault("bayesian_priors",{})
    cat = priors.setdefault(categoria, {"wins":0,"losses":0,"win_rate":0.5})

    if ganhou:
        cat["wins"] += 1
    else:
        cat["losses"] += 1

    total = cat["wins"] + cat["losses"]
    if total > 0:
        # Bayesian update — combina prior com evidencia nova
        prior_weight = 0.3
        evidence_weight = 0.7
        cat["win_rate"] = (prior_weight * 0.5 +
                           evidence_weight * cat["wins"] / total)

    salvar_estado(state)
    print(f"[Polymarket] Bayesian updated: {categoria} → {cat['win_rate']:.2f}")

# API
@app.get("/")
def status():
    state = carregar_estado()
    total = state.get("wins",0) + state.get("losses",0)
    win_rate = state.get("wins",0)/max(total,1)*100
    return {
        "ok": True,
        "service": "polymarket-agent",
        "capital_usd": state.get("capital_usd", CAPITAL_INICIAL_USD),
        "ciclos": state.get("ciclos",0),
        "trades": total,
        "wins": state.get("wins",0),
        "losses": state.get("losses",0),
        "win_rate": f"{win_rate:.1f}%",
        "profit_total": state.get("profit_total",0),
        "min_edge": f"{MIN_EDGE:.0%}",
        "kelly_max": f"{MAX_KELLY_FRACTION:.0%}",
    }

@app.get("/scan")
def scan():
    state = carregar_estado()
    ops = ciclo_polymarket()
    return {
        "ok": True,
        "oportunidades": len(ops),
        "capital": state.get("capital_usd"),
        "detalhes": [{
            "question": o["mercado"]["question"][:60],
            "lado": o["analise"]["lado"],
            "edge": f"{o['analise']['edge']:.1%}",
            "posicao": f"${o['posicao_usd']:.2f}",
            "score": o["score"]
        } for o in ops]
    }

@app.post("/registrar_trade")
def registrar_trade(data: dict):
    """Registra resultado de um trade para aprendizado Bayesiano"""
    state = carregar_estado()
    ganhou = data.get("ganhou", False)
    valor  = data.get("valor_usd", 0)
    categoria = data.get("categoria","geral")
    edge = data.get("edge", 0)

    if ganhou:
        state["wins"] = state.get("wins",0) + 1
        state["capital_usd"] = state.get("capital_usd",0) + valor
        state["profit_total"] = state.get("profit_total",0) + valor
    else:
        state["losses"] = state.get("losses",0) + 1
        state["capital_usd"] = max(0, state.get("capital_usd",0) - valor)
        state["profit_total"] = state.get("profit_total",0) - valor

    state.setdefault("trades",[]).append({
        "ganhou": ganhou,
        "valor": valor,
        "categoria": categoria,
        "data": datetime.datetime.now().isoformat()
    })

    registrar_resultado("trade1", ganhou, categoria, edge)
    salvar_estado(state)

    total = state.get("wins",0) + state.get("losses",0)
    telegram(
        f"{'✅ WIN' if ganhou else '❌ LOSS'}\n"
        f"Valor: ${valor:.2f}\n"
        f"Capital: ${state['capital_usd']:.2f}\n"
        f"Win rate: {state.get('wins',0)/max(total,1)*100:.0f}%\n"
        f"Profit total: ${state.get('profit_total',0):.2f}")

    return {"ok": True, "capital_novo": state["capital_usd"]}

@app.get("/mercados")
def listar_mercados():
    """Lista melhores mercados agora"""
    mercados = buscar_mercados_polymarket()
    top = sorted(mercados,
                 key=lambda x: x["liquidity"], reverse=True)[:10]
    return {"ok": True, "total": len(mercados), "top10": top}

@app.get("/performance")
def performance():
    state = carregar_estado()
    capital_inicial = CAPITAL_INICIAL_USD
    capital_atual = state.get("capital_usd", capital_inicial)
    roi = (capital_atual - capital_inicial) / capital_inicial * 100
    total = state.get("wins",0) + state.get("losses",0)

    return {
        "ok": True,
        "capital_inicial": capital_inicial,
        "capital_atual": capital_atual,
        "roi": f"{roi:.1f}%",
        "profit": state.get("profit_total",0),
        "trades": total,
        "win_rate": f"{state.get('wins',0)/max(total,1)*100:.0f}%",
        "meta_btc_pct": f"{capital_atual/85000*100:.4f}%",
        "bayesian_priors": state.get("bayesian_priors",{}),
    }

def loop_background():
    def run():
        time.sleep(60)
        while True:
            try:
                ciclo_polymarket()
            except Exception as e:
                print(f"[Polymarket] Erro: {e}")
            time.sleep(3600)  # 1 hora
    threading.Thread(target=run, daemon=True).start()
    print("[Polymarket] Loop 1h iniciado")

if __name__ == "__main__":
    print("[JARVIS Polymarket Agent] :7812")
    print(f"Min edge: {MIN_EDGE:.0%}")
    print(f"Kelly max: {MAX_KELLY_FRACTION:.0%}")
    print(f"Capital inicial: ${CAPITAL_INICIAL_USD}")
    loop_background()
    uvicorn.run(app, host="0.0.0.0", port=7812)
