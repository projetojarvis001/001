#!/usr/bin/env python3
"""
JARVIS CRYPTO STRATEGY :7811
Diretiva: Evoluir tudo que for adquirido ate 1 BTC
Estrategia: Zero capital → airdrops → staking → compound → 1 BTC
Carteiras alvo: BTC ETH ETC SOL BNB POL (Wagner Coinomi)
"""
import sys, os, json, time, datetime, requests, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Crypto Strategy v1")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID        = "170323936"
STATE_FILE     = "/Users/jarvis001/jarvis/data/strategy_state.json"

# CARTEIRAS WAGNER — DESTINO FINAL
CARTEIRAS_WAGNER = {
    "BTC": "bc1qnn7kz6ps8xz586y8dnqtm7y4d24rvjcz2ar9dc",
    "ETH": "0x306b7e7eB0cC178f9E7315962521958eb23DC0a",
    "ETC": "0x6fbA95c6c4DACBfBC83Ce16D452A2f3837FD93dE",
    "SOL": "5UBZfckYRpTyjiqemY7sysyCXhTMoYSmYDDt61zkf6X",
    "BNB": "0xB879806D640fd508FCac94544c28D22f98266990A",
    "POL": "0x306b7e7eB0cC178f9E7315962521958eb23DC0a",
}

# META FINAL
META_BTC       = 1.0        # 1 Bitcoin
META_USD       = 85000      # ~1 BTC em USD hoje

# Fases de evolucao
FASES = {
    1: {"nome": "Coleta",     "meta_usd": 100,    "estrategia": "airdrops + faucets + learn-to-earn"},
    2: {"nome": "Acumulacao", "meta_usd": 1000,   "estrategia": "staking tokens recebidos + novos airdrops"},
    3: {"nome": "Crescimento","meta_usd": 5000,   "estrategia": "DeFi yield + LP + ambassador programs"},
    4: {"nome": "Escala",     "meta_usd": 20000,  "estrategia": "compound automatico + melhores yields"},
    5: {"nome": "Bitcoin",    "meta_usd": 85000,  "estrategia": "conversao gradual para BTC"},
}

def telegram(msg: str):
    if not TELEGRAM_TOKEN: return
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID, "text": msg, "parse_mode": "HTML"},
            timeout=10)
    except: pass

def carregar_estado():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as f:
                return json.load(f)
    except: pass
    return {
        "portfolio": {
            "BTC": 0.0, "ETH": 0.0, "ETC": 0.0,
            "SOL": 0.0, "BNB": 0.0, "POL": 0.0,
            "USD_total": 0.0
        },
        "fase_atual": 1,
        "historico": [],
        "total_recebido_usd": 0.0,
        "total_convertido_btc": 0.0,
        "meta_btc": META_BTC,
        "criado_em": datetime.datetime.now().isoformat()
    }

def salvar_estado(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE,"w") as f:
        json.dump(state, f, indent=2)

def preco_btc_usd() -> float:
    try:
        r = requests.get(
            "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
            timeout=10)
        return r.json()["bitcoin"]["usd"]
    except:
        return 85000.0

def precos_portfolio() -> dict:
    try:
        r = requests.get(
            "https://api.coingecko.com/api/v3/simple/price"
            "?ids=bitcoin,ethereum,ethereum-classic,solana,binancecoin,matic-network"
            "&vs_currencies=usd,brl",
            timeout=10)
        data = r.json()
        return {
            "BTC": data.get("bitcoin",{}).get("usd",85000),
            "ETH": data.get("ethereum",{}).get("usd",2400),
            "ETC": data.get("ethereum-classic",{}).get("usd",9),
            "SOL": data.get("solana",{}).get("usd",90),
            "BNB": data.get("binancecoin",{}).get("usd",600),
            "POL": data.get("matic-network",{}).get("usd",0.3),
            "BRL_BTC": data.get("bitcoin",{}).get("brl",430000),
        }
    except:
        return {"BTC":85000,"ETH":2400,"ETC":9,"SOL":90,"BNB":600,"POL":0.3,"BRL_BTC":430000}

def calcular_portfolio_usd(portfolio: dict, precos: dict) -> float:
    total = 0
    for moeda, qtd in portfolio.items():
        if moeda == "USD_total": continue
        preco = precos.get(moeda, 0)
        total += float(qtd) * float(preco)
    return total

def determinar_fase(total_usd: float) -> int:
    for fase, info in sorted(FASES.items(), reverse=True):
        if total_usd >= info["meta_usd"] * 0.1:
            return fase
    return 1

def recomendar_estrategia(fase: int, portfolio: dict, precos: dict) -> str:
    """Usa LLM para recomendar proxima acao baseada no portfolio atual"""
    try:
        from cost_router import ask
        portfolio_str = ", ".join([
            f"{m}: {v:.6f} (${float(v)*precos.get(m,0):.2f})"
            for m,v in portfolio.items()
            if m != "USD_total" and float(v) > 0
        ])
        total_usd = calcular_portfolio_usd(portfolio, precos)
        fase_info = FASES.get(fase, FASES[1])
        prox_meta = FASES.get(fase+1, FASES[5])

        prompt = f"""Voce gerencia um portfolio cripto com objetivo de chegar a 1 BTC.

Portfolio atual: {portfolio_str if portfolio_str else "vazio — apenas airdrops pendentes"}
Total USD: ${total_usd:.2f}
Fase: {fase} — {fase_info['nome']} (meta: ${fase_info['meta_usd']})
Proxima fase: ${prox_meta['meta_usd']}
Preco BTC: ${precos.get('BTC',85000):,.0f}
Progresso para 1 BTC: {total_usd/META_USD*100:.2f}%

Recomende em 2-3 linhas a melhor acao AGORA para maximizar crescimento sem capital adicional.
Seja especifico: qual plataforma, qual acao, qual token priorizar."""

        resp = ask(prompt, system="Especialista DeFi. Seja direto e especifico.")
        return resp.get("content","")[:300]
    except:
        return FASES.get(fase, FASES[1])["estrategia"]

def relatorio_diario():
    """Relatorio diario de progresso — enviado no Telegram"""
    state = carregar_estado()
    portfolio = state.get("portfolio",{})
    precos = precos_portfolio()
    total_usd = calcular_portfolio_usd(portfolio, precos)
    btc_price = precos.get("BTC", 85000)
    btc_equiv = total_usd / btc_price
    progresso = btc_equiv / META_BTC * 100
    fase = determinar_fase(total_usd)
    fase_info = FASES.get(fase, FASES[1])

    # Barra de progresso
    blocos = int(progresso / 5)
    barra = "█" * blocos + "░" * (20 - blocos)

    recomendacao = recomendar_estrategia(fase, portfolio, precos)

    msg = (
        f"📊 <b>JARVIS — RELATÓRIO CRIPTO</b>\n"
        f"{datetime.datetime.now().strftime('%d/%m/%Y %H:%M')}\n\n"
        f"<b>META: 1 BTC = ${btc_price:,.0f}</b>\n\n"
        f"[{barra}] {progresso:.3f}%\n\n"
        f"💼 Portfolio: ${total_usd:.2f}\n"
        f"₿ Equivalente BTC: {btc_equiv:.6f}\n"
        f"📈 Fase: {fase} — {fase_info['nome']}\n\n"
    )

    # Moedas com saldo
    tem_saldo = False
    for moeda, qtd in portfolio.items():
        if moeda == "USD_total": continue
        if float(qtd) > 0:
            val_usd = float(qtd) * precos.get(moeda,0)
            msg += f"  {moeda}: {float(qtd):.6f} (${val_usd:.2f})\n"
            tem_saldo = True

    if not tem_saldo:
        msg += f"  Aguardando primeiros airdrops...\n"

    msg += (
        f"\n🎯 <b>Estratégia atual:</b>\n{fase_info['estrategia']}\n\n"
        f"🤖 <b>Próxima ação:</b>\n{recomendacao[:200]}\n\n"
        f"👛 Carteiras alvo configuradas: {len(CARTEIRAS_WAGNER)}"
    )

    telegram(msg)
    return state

def registrar_recebimento(moeda: str, quantidade: float, origem: str):
    """Registra token recebido e decide proxima acao"""
    state = carregar_estado()
    precos = precos_portfolio()

    portfolio = state.get("portfolio",{})
    portfolio[moeda] = float(portfolio.get(moeda, 0)) + quantidade
    valor_usd = quantidade * precos.get(moeda, 0)
    valor_brl = valor_usd * 5.0  # aproximado

    total_usd = calcular_portfolio_usd(portfolio, precos)
    btc_equiv = total_usd / precos.get("BTC", 85000)
    fase = determinar_fase(total_usd)

    state["portfolio"] = portfolio
    state["total_recebido_usd"] = state.get("total_recebido_usd",0) + valor_usd
    state["fase_atual"] = fase
    state.setdefault("historico",[]).append({
        "moeda": moeda,
        "quantidade": quantidade,
        "valor_usd": valor_usd,
        "origem": origem,
        "data": datetime.datetime.now().isoformat()
    })

    salvar_estado(state)

    # Notifica Wagner
    prox_fase = FASES.get(fase+1, FASES[5])
    falta_usd = max(0, prox_fase["meta_usd"] - total_usd)

    msg = (
        f"💰 <b>TOKEN RECEBIDO</b>\n\n"
        f"Moeda: {moeda}\n"
        f"Quantidade: {quantidade:.6f}\n"
        f"Valor: ${valor_usd:.2f} (~R${valor_brl:.2f})\n"
        f"Origem: {origem}\n\n"
        f"📊 Portfolio total: ${total_usd:.2f}\n"
        f"₿ Equiv BTC: {btc_equiv:.6f} / 1.0\n"
        f"📈 Fase: {fase} — {FASES[fase]['nome']}\n"
        f"🎯 Prox fase: falta ${falta_usd:.2f}\n\n"
        f"👛 Carteira destino: {CARTEIRAS_WAGNER.get(moeda,'verificar')[:30]}..."
    )
    telegram(msg)
    return state

# API
@app.get("/")
def status():
    state = carregar_estado()
    precos = precos_portfolio()
    portfolio = state.get("portfolio",{})
    total_usd = calcular_portfolio_usd(portfolio, precos)
    btc_price = precos.get("BTC",85000)
    return {
        "ok": True,
        "service": "crypto-strategy",
        "meta": "1 BTC",
        "portfolio_usd": round(total_usd, 2),
        "btc_equivalente": round(total_usd/btc_price, 6),
        "progresso_pct": round(total_usd/META_USD*100, 4),
        "fase_atual": state.get("fase_atual",1),
        "fase_nome": FASES.get(state.get("fase_atual",1),{}).get("nome","Coleta"),
        "carteiras_wagner": CARTEIRAS_WAGNER,
        "preco_btc_usd": btc_price,
    }

@app.get("/relatorio")
def get_relatorio():
    state = relatorio_diario()
    return {"ok": True, "enviado_telegram": True}

@app.post("/registrar")
def registrar(data: dict):
    moeda    = data.get("moeda","").upper()
    qtd      = float(data.get("quantidade",0))
    origem   = data.get("origem","airdrop")
    if moeda and qtd > 0:
        state = registrar_recebimento(moeda, qtd, origem)
        precos = precos_portfolio()
        total = calcular_portfolio_usd(state["portfolio"], precos)
        return {"ok": True, "portfolio_usd": total,
                "btc_equiv": total/precos.get("BTC",85000)}
    return {"ok": False}

@app.get("/progresso")
def progresso():
    state = carregar_estado()
    precos = precos_portfolio()
    portfolio = state.get("portfolio",{})
    total_usd = calcular_portfolio_usd(portfolio, precos)
    btc_price = precos.get("BTC",85000)
    btc_equiv = total_usd / btc_price
    pct = btc_equiv / META_BTC * 100

    fases_status = {}
    for f, info in FASES.items():
        fases_status[f] = {
            "nome": info["nome"],
            "meta_usd": info["meta_usd"],
            "atingida": total_usd >= info["meta_usd"],
            "progresso_pct": min(100, total_usd/info["meta_usd"]*100)
        }

    return {
        "ok": True,
        "portfolio_usd": round(total_usd, 2),
        "btc_equivalente": round(btc_equiv, 8),
        "progresso_para_1btc": f"{pct:.4f}%",
        "fases": fases_status,
        "carteiras_destino": CARTEIRAS_WAGNER
    }

def loop_background():
    def run():
        time.sleep(60)
        hora_relatorio = 8  # Relatorio diario 8h
        while True:
            try:
                hora = datetime.datetime.now().hour
                minuto = datetime.datetime.now().minute
                if hora == hora_relatorio and minuto < 5:
                    relatorio_diario()
                    time.sleep(300)
            except Exception as e:
                print(f"[Strategy] Erro: {e}")
            time.sleep(60)
    threading.Thread(target=run, daemon=True).start()
    print("[Crypto Strategy] Relatorio diario 8h")

if __name__ == "__main__":
    print("[JARVIS Crypto Strategy] :7811")
    print(f"Meta: 1 BTC = ${META_USD:,}")
    print(f"Carteiras Wagner: {list(CARTEIRAS_WAGNER.keys())}")
    loop_background()
    uvicorn.run(app, host="0.0.0.0", port=7811)
