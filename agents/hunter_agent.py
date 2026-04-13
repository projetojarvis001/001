#!/usr/bin/env python3
"""
Módulo Hunter — Caçador de Oportunidades
Monitora: airdrops, arbitragem cripto, DePIN, oportunidades de mercado
Reporta via Telegram sem intervenção humana
"""
import sys, os, warnings, json, requests, time
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage

load_dotenv("/Users/jarvis001/jarvis/.env")
GROQ_KEY = os.getenv("GROQ_API_KEY")
BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.1)

def notify(msg):
    try:
        requests.post(
            f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"},
            timeout=10
        )
    except: pass

def get_crypto_prices():
    """Busca preços reais de BTC, ETH, BNB via CoinGecko API gratuita"""
    try:
        r = requests.get(
            "https://api.coingecko.com/api/v3/simple/price",
            params={"ids": "bitcoin,ethereum,binancecoin,solana", "vs_currencies": "usd,brl",
                    "include_24hr_change": "true", "include_market_cap": "true"},
            timeout=15
        )
        if r.status_code == 200:
            return r.json()
    except: pass
    return {}

def get_trending_coins():
    """Busca moedas em tendência via CoinGecko"""
    try:
        r = requests.get("https://api.coingecko.com/api/v3/search/trending", timeout=15)
        if r.status_code == 200:
            coins = r.json().get("coins", [])[:5]
            return [{"name": c["item"]["name"], "symbol": c["item"]["symbol"],
                     "rank": c["item"]["market_cap_rank"]} for c in coins]
    except: pass
    return []

def get_fear_greed():
    """Índice Fear & Greed do mercado cripto"""
    try:
        r = requests.get("https://api.alternative.me/fng/?limit=1", timeout=10)
        if r.status_code == 200:
            data = r.json().get("data", [{}])[0]
            return {"value": data.get("value"), "label": data.get("value_classification")}
    except: pass
    return {}

def get_defi_opportunities():
    """Busca oportunidades DeFi via DeFi Llama"""
    try:
        r = requests.get("https://yields.llama.fi/pools", timeout=20)
        if r.status_code == 200:
            pools = r.json().get("data", [])
            # Filtra pools com APY > 10% e TVL > 1M
            good = [p for p in pools
                    if p.get("apy", 0) > 10
                    and p.get("tvlUsd", 0) > 1_000_000
                    and p.get("stablecoin", False)]
            good.sort(key=lambda x: x.get("apy", 0), reverse=True)
            return good[:5]
    except: pass
    return []

def hunt(query="oportunidades gerais"):
    print(f"[Hunter] Caçando: {query[:60]}")

    # Coleta dados reais
    prices = get_crypto_prices()
    trending = get_trending_coins()
    fear_greed = get_fear_greed()
    defi = get_defi_opportunities()

    # Monta contexto
    btc_price = prices.get("bitcoin", {}).get("usd", "?")
    btc_change = prices.get("bitcoin", {}).get("usd_24h_change", 0)
    eth_price = prices.get("ethereum", {}).get("usd", "?")
    btc_brl = prices.get("bitcoin", {}).get("brl", "?")
    fg_value = fear_greed.get("value", "?")
    fg_label = fear_greed.get("label", "?")

    trending_str = ", ".join([f"{c['name']} ({c['symbol']})" for c in trending])

    defi_str = ""
    if defi:
        defi_str = "\n".join([
            f"- {p.get('project','?')} {p.get('symbol','?')}: APY {p.get('apy',0):.1f}% TVL ${p.get('tvlUsd',0)/1e6:.1f}M chain {p.get('chain','?')}"
            for p in defi[:3]
        ])

    market_data = f"""
DADOS DE MERCADO EM TEMPO REAL:
BTC: ${btc_price:,} (BRL R${btc_brl:,}) | 24h: {btc_change:.2f}%
ETH: ${eth_price:,}
Fear & Greed Index: {fg_value}/100 — {fg_label}
Trending: {trending_str}

TOP OPORTUNIDADES DEFI (stablecoins, APY>10%, TVL>$1M):
{defi_str if defi_str else "Nenhuma encontrada agora"}
"""

    # LLM analisa e recomenda
    response = llm.invoke([
        SystemMessage(content="""Você é o Módulo Hunter do JARVIS — especialista em identificar oportunidades de geração de valor no mercado cripto e DeFi para Wagner Silva.
Analise os dados de mercado em tempo real e identifique:
1. Se é bom momento para comprar/vender BTC ou ETH
2. Oportunidades DeFi com melhor relação risco/retorno
3. Qualquer sinal relevante para ação imediata
Seja direto, específico e use os números reais fornecidos.
Responda em português do Brasil."""),
        HumanMessage(content=f"{market_data}\n\nPergunta: {query}")
    ])

    return {
        "prices": prices,
        "fear_greed": fear_greed,
        "trending": trending,
        "defi_top": defi[:3] if defi else [],
        "analysis": response.content
    }

def run_hunt_report():
    """Gera relatório completo e envia no Telegram"""
    data = hunt("análise geral do mercado e melhores oportunidades agora")

    prices = data.get("prices", {})
    btc = prices.get("bitcoin", {})
    eth = prices.get("ethereum", {})
    fg = data.get("fear_greed", {})
    trending = data.get("trending", [])
    defi = data.get("defi_top", [])

    trending_str = ", ".join([f"{c['name']}" for c in trending[:3]])

    defi_lines = "\n".join([
        f"  • {p.get('project','?')} {p.get('symbol','?')}: {p.get('apy',0):.1f}% APY"
        for p in defi
    ]) if defi else "  Nenhuma disponível"

    msg = f"""🔍 *Hunter Report — JARVIS*

💰 *Preços Atuais*
- BTC: ${btc.get('usd', '?'):,} | {btc.get('usd_24h_change', 0):.2f}% 24h
- ETH: ${eth.get('usd', '?'):,} | {eth.get('usd_24h_change', 0):.2f}% 24h
- BTC/BRL: R${btc.get('brl', '?'):,}

😱 *Fear & Greed:* {fg.get('value', '?')}/100 — {fg.get('label', '?')}
📈 *Trending:* {trending_str}

🌾 *DeFi Oportunidades*
{defi_lines}

🤖 *Análise JARVIS:*
{data.get('analysis', '')[:500]}"""

    notify(msg)
    print(f"[Hunter] Relatório enviado")
    return data

if __name__ == "__main__":
    import sys
    query = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "analise geral"
    if query == "report":
        run_hunt_report()
    else:
        result = hunt(query)
        print(f"\nANÁLISE:\n{result['analysis']}")
