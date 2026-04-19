#!/usr/bin/env python3
"""
JARVIS Daily Report
Envia relatório completo todo dia às 08:00
Mostra evolução, conquistas e próximas ações
"""
import sys, os, json, requests, time, datetime
sys.path.insert(0,'/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

TOKEN   = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID = "170323936"
HISTORY_FILE = "/Users/jarvis001/jarvis/data/portfolio_history.json"

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID, "text": msg, "parse_mode": "HTML"},
            timeout=10)
    except: pass

def get_usdc_balance(addr):
    try:
        r = requests.post("https://polygon-rpc.com",
            json={"jsonrpc":"2.0","id":1,"method":"eth_call",
                  "params":[{"to":"0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
                             "data":"0x70a08231000000000000000000000000"+addr[2:].lower()},
                            "latest"]},
            timeout=10)
        return int(r.json().get("result","0x0"),16) / 1e6
    except: return 0.0

def get_btc_price():
    try:
        r = requests.get(
            "https://api.coingecko.com/api/v3/simple/price",
            params={"ids":"bitcoin","vs_currencies":"usd"},
            timeout=10)
        return r.json().get("bitcoin",{}).get("usd",85000)
    except: return 85000

def load_history():
    try:
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE) as f:
                return json.load(f)
    except: pass
    return {"dias": [], "inicio": datetime.datetime.now().isoformat()}

def save_history(h):
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    with open(HISTORY_FILE,"w") as f:
        json.dump(h, f, indent=2)

def gerar_relatorio():
    hoje = datetime.datetime.now().strftime("%d/%m/%Y")
    hora = datetime.datetime.now().strftime("%H:%M")

    # Saldos
    wallet     = os.getenv("POLYMARKET_ADDRESS","0x5565A299aD71615eB9D6671Ee9ea4c2444417448")
    usdc_bal   = get_usdc_balance(wallet)
    btc_price  = get_btc_price()
    usdc_em_btc = usdc_bal / btc_price if btc_price > 0 else 0

    # Airdrops
    airdrop_state = {}
    try:
        with open("/Users/jarvis001/jarvis/data/executor_state.json") as f:
            airdrop_state = json.load(f)
    except: pass

    airdrops_ativos = len([c for c in airdrop_state.get("cadastros",[])
                           if c.get("sucesso")])

    # Polymarket
    poly_state = {}
    try:
        with open("/Users/jarvis001/jarvis/data/polymarket_state.json") as f:
            poly_state = json.load(f)
    except: pass

    capital_poly  = poly_state.get("capital_usd", 0)
    profit_poly   = poly_state.get("profit_total", 0)
    wins          = poly_state.get("wins", 0)
    losses        = poly_state.get("losses", 0)
    total_trades  = wins + losses
    win_rate      = (wins/total_trades*100) if total_trades > 0 else 0

    # Historico
    history = load_history()
    dias    = history.get("dias",[])

    # Ontem
    ontem_usdc = dias[-1].get("usdc",0) if dias else 0
    variacao   = usdc_bal - ontem_usdc
    var_pct    = (variacao/ontem_usdc*100) if ontem_usdc > 0 else 0

    # Salva hoje
    dias.append({
        "data":    hoje,
        "usdc":    usdc_bal,
        "airdrops": airdrops_ativos,
        "trades":  total_trades,
        "profit":  profit_poly,
    })
    history["dias"] = dias[-30:]  # ultimos 30 dias
    save_history(history)

    # Meta BTC
    meta_btc    = 85000
    pct_meta    = (usdc_bal / meta_btc * 100)
    falta_usd   = meta_btc - usdc_bal

    # Fase atual
    if usdc_bal < 100:
        fase = "1 — Coleta (meta $100)"
        proxima = "$100"
    elif usdc_bal < 1000:
        fase = "2 — Acumulacao (meta $1.000)"
        proxima = "$1.000"
    elif usdc_bal < 5000:
        fase = "3 — Crescimento (meta $5.000)"
        proxima = "$5.000"
    elif usdc_bal < 20000:
        fase = "4 — Escala (meta $20.000)"
        proxima = "$20.000"
    else:
        fase = "5 — Bitcoin (meta $85.000)"
        proxima = "1 BTC"

    # Proximas acoes
    acoes = []
    if usdc_bal == 0:
        acoes.append("⚠️ Aguardando USDC chegar na wallet")
    pol_bal = 0
    try:
        r = requests.post("https://polygon-rpc.com",
            json={"jsonrpc":"2.0","id":1,"method":"eth_getBalance",
                  "params":[wallet,"latest"]},timeout=5)
        pol_bal = int(r.json().get("result","0x0"),16)/1e18
    except: pass

    if pol_bal < 0.1:
        acoes.append("⚠️ Comprar $2 POL para gas na Binance")
    if usdc_bal >= 200:
        acoes.append("💡 Portfolio $200+ — hora de integrar TradingView")
    if usdc_bal >= 1000:
        acoes.append("💰 $1.000+ — iniciar staking DeFi")
    if not acoes:
        acoes.append("✅ Sistema operando normalmente")

    # Monta mensagem
    variacao_str = f"+${variacao:.2f}" if variacao >= 0 else f"-${abs(variacao):.2f}"
    var_emoji    = "📈" if variacao >= 0 else "📉"

    msg = (
        f"📊 <b>JARVIS — RELATÓRIO DIÁRIO</b>\n"
        f"{hoje} {hora}\n\n"
        f"💰 <b>PORTFOLIO</b>\n"
        f"  Saldo:    ${usdc_bal:.2f} USDC\n"
        f"  Ontem:    ${ontem_usdc:.2f}\n"
        f"  Variação: {var_emoji} {variacao_str} ({var_pct:+.1f}%)\n\n"
        f"₿ <b>META 1 BTC</b>\n"
        f"  Progresso: {pct_meta:.4f}%\n"
        f"  BTC hoje:  ${btc_price:,.0f}\n"
        f"  Falta:     ${falta_usd:,.0f}\n"
        f"  Fase:      {fase}\n\n"
        f"🎯 <b>PREDICTION MARKETS</b>\n"
        f"  Capital:   ${capital_poly:.2f}\n"
        f"  Profit:    ${profit_poly:.2f}\n"
        f"  Trades:    {total_trades} ({wins}W/{losses}L)\n"
        f"  Win rate:  {win_rate:.0f}%\n\n"
        f"🪂 <b>AIRDROPS</b>\n"
        f"  Ativos:    {airdrops_ativos} cadastros\n"
        f"  Aguardando distribuição\n\n"
        f"⚡ <b>PRÓXIMAS AÇÕES</b>\n"
    )
    for acao in acoes:
        msg += f"  {acao}\n"

    # Historico 7 dias
    if len(dias) >= 2:
        msg += f"\n📈 <b>EVOLUÇÃO 7 DIAS</b>\n"
        for d in dias[-7:]:
            msg += f"  {d['data']}: ${d['usdc']:.2f}\n"

    return msg

if __name__ == "__main__":
    print("Gerando relatório...")
    msg = gerar_relatorio()
    print(msg)
    telegram(msg)
    print("Enviado para Telegram!")
