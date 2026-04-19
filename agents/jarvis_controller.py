#!/usr/bin/env python3
"""
JARVIS CONTROLLER :7813
Kill switch + aprovacao rapida via Telegram
Comandos:
  /pausar   — pausa todas as operacoes autonomas
  /retomar  — retoma operacoes autonomas
  /status   — estado atual do sistema
  /sim      — aprova operacao pendente
  /nao      — rejeita operacao pendente
  /limite X — muda limite por operacao
"""
import sys, os, json, time, datetime, requests, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Controller v1")

TOKEN     = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID   = "170323936"
KS_FILE   = "/Users/jarvis001/jarvis/data/kill_switch.json"
PEND_FILE = "/Users/jarvis001/jarvis/data/pendentes.json"

def ks():
    try:
        with open(KS_FILE) as f:
            return json.load(f)
    except:
        return {"autonomo":True,"pausado":False,
                "threshold_auto":70,"max_valor_auto_usd":5.0,
                "operacoes_hoje":0,"max_operacoes_dia":10,"log":[]}

def salvar_ks(state):
    with open(KS_FILE,"w") as f:
        json.dump(state, f, indent=2)

def pendentes():
    try:
        with open(PEND_FILE) as f:
            return json.load(f)
    except:
        return []

def salvar_pendentes(p):
    with open(PEND_FILE,"w") as f:
        json.dump(p, f, indent=2)

def telegram(msg: str):
    if not TOKEN: return
    try:
        requests.post(
            f"https://api.telegram.org/bot{TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID, "text": msg,
                  "parse_mode": "HTML"},
            timeout=10)
    except: pass

def pode_agir_autonomo(score: float, valor_usd: float) -> dict:
    """Verifica se JARVIS pode agir sozinho"""
    state = ks()

    if state.get("pausado"):
        return {"pode": False, "motivo": "sistema pausado — /retomar para reativar"}

    if state.get("operacoes_hoje",0) >= state.get("max_operacoes_dia",10):
        return {"pode": False, "motivo": f"limite diario atingido ({state['max_operacoes_dia']})"}

    if score < state.get("threshold_auto",70):
        return {"pode": False, "motivo": f"score {score} abaixo do threshold {state['threshold_auto']}"}

    if valor_usd > state.get("max_valor_auto_usd",5.0):
        return {"pode": False, "motivo": f"valor ${valor_usd} acima do limite ${state['max_valor_auto_usd']}"}

    return {"pode": True, "motivo": "autonomo autorizado"}

def registrar_operacao(descricao: str, valor: float, score: float):
    """Registra operacao executada autonomamente"""
    state = ks()
    state["operacoes_hoje"] = state.get("operacoes_hoje",0) + 1
    state.setdefault("log",[]).append({
        "descricao": descricao[:80],
        "valor": valor,
        "score": score,
        "quando": datetime.datetime.now().isoformat()
    })
    # Limita log a 100 entradas
    if len(state["log"]) > 100:
        state["log"] = state["log"][-50:]
    salvar_ks(state)

def adicionar_pendente(op: dict) -> str:
    """Adiciona operacao pendente de aprovacao"""
    pend = pendentes()
    op_id = f"op_{int(time.time())}"
    op["id"] = op_id
    op["criado_em"] = datetime.datetime.now().isoformat()
    pend.append(op)
    salvar_pendentes(pend)

    # Alerta Wagner
    telegram(
        f"⏳ <b>AGUARDA APROVACAO</b>\n\n"
        f"{op.get('descricao','?')}\n\n"
        f"💰 Valor: ${op.get('valor',0):.2f}\n"
        f"📊 Score: {op.get('score',0):.0f}/100\n"
        f"⏰ Expira em: 30 min\n\n"
        f"✅ /sim — aprovar\n"
        f"❌ /nao — rejeitar"
    )
    return op_id

# Loop que monitora comandos Telegram
def monitor_telegram():
    offset = 0
    while True:
        try:
            r = requests.get(
                f"https://api.telegram.org/bot{TOKEN}/getUpdates",
                params={"offset": offset, "timeout": 30},
                timeout=35)
            updates = r.json().get("result",[])

            for upd in updates:
                offset = upd["update_id"] + 1
                msg = upd.get("message",{})
                chat = msg.get("chat",{}).get("id","")
                text = msg.get("text","").strip().lower()

                # So aceita comandos do chat autorizado
                if str(chat) != str(CHAT_ID):
                    continue

                state = ks()

                if text == "/pausar":
                    state["pausado"] = True
                    state["pausado_em"] = datetime.datetime.now().isoformat()
                    salvar_ks(state)
                    telegram("🛑 <b>JARVIS PAUSADO</b>\nTodas as operacoes autonomas suspensas.\n/retomar para reativar.")

                elif text == "/retomar":
                    state["pausado"] = False
                    state["pausado_em"] = None
                    salvar_ks(state)
                    telegram("✅ <b>JARVIS RETOMADO</b>\nOperacoes autonomas reativadas.")

                elif text == "/status":
                    pend = pendentes()
                    ops_hoje = state.get("operacoes_hoje",0)
                    log = state.get("log",[])
                    telegram(
                        f"📊 <b>JARVIS STATUS</b>\n\n"
                        f"{'🛑 PAUSADO' if state.get('pausado') else '✅ ATIVO'}\n"
                        f"Threshold: score >= {state.get('threshold_auto',70)}\n"
                        f"Limite/op: ${state.get('max_valor_auto_usd',5)}\n"
                        f"Ops hoje: {ops_hoje}/{state.get('max_operacoes_dia',10)}\n"
                        f"Pendentes: {len(pend)}\n"
                        f"Ultima op: {log[-1]['descricao'][:40] if log else 'nenhuma'}"
                    )

                elif text == "/sim":
                    pend = pendentes()
                    if pend:
                        op = pend.pop(0)
                        salvar_pendentes(pend)
                        registrar_operacao(op.get("descricao",""), op.get("valor",0), op.get("score",0))
                        telegram(f"✅ <b>APROVADO E EXECUTADO</b>\n{op.get('descricao','')[:60]}\nValor: ${op.get('valor',0):.2f}")
                    else:
                        telegram("Nenhuma operacao pendente.")

                elif text == "/nao":
                    pend = pendentes()
                    if pend:
                        op = pend.pop(0)
                        salvar_pendentes(pend)
                        telegram(f"❌ <b>REJEITADO</b>\n{op.get('descricao','')[:60]}")
                    else:
                        telegram("Nenhuma operacao pendente.")

                elif text.startswith("/limite"):
                    try:
                        novo = float(text.split()[1])
                        state["max_valor_auto_usd"] = novo
                        salvar_ks(state)
                        telegram(f"✅ Limite por operacao: ${novo:.2f}")
                    except:
                        telegram("Uso: /limite 10 (define limite em $)")

                elif text == "/log":
                    log = state.get("log",[])[-5:]
                    if log:
                        msg_log = "<b>Ultimas operacoes:</b>\n"
                        for l in log:
                            msg_log += f"  • {l['descricao'][:40]} ${l['valor']:.2f}\n"
                        telegram(msg_log)
                    else:
                        telegram("Nenhuma operacao registrada.")

                elif text == "/ajuda":
                    telegram(
                        "<b>JARVIS COMANDOS:</b>\n\n"
                        "/pausar  — para tudo\n"
                        "/retomar — reativa\n"
                        "/status  — estado atual\n"
                        "/sim     — aprova pendente\n"
                        "/nao     — rejeita pendente\n"
                        "/limite X — muda limite $\n"
                        "/log     — ultimas operacoes\n"
                        "/ajuda   — esta mensagem"
                    )

        except Exception as e:
            print(f"[Controller] Erro Telegram: {e}")
            time.sleep(5)

# Reset operacoes_hoje a meia noite
def reset_diario():
    while True:
        now = datetime.datetime.now()
        segundos_ate_meia_noite = (
            (24 - now.hour - 1) * 3600 +
            (60 - now.minute - 1) * 60 +
            (60 - now.second))
        time.sleep(segundos_ate_meia_noite)
        state = ks()
        state["operacoes_hoje"] = 0
        salvar_ks(state)
        print("[Controller] Reset diario operacoes")

# API
@app.get("/")
def status():
    state = ks()
    pend = pendentes()
    return {
        "ok": True,
        "service": "jarvis-controller",
        "autonomo": state.get("autonomo"),
        "pausado": state.get("pausado"),
        "threshold": state.get("threshold_auto"),
        "max_valor_usd": state.get("max_valor_auto_usd"),
        "operacoes_hoje": state.get("operacoes_hoje",0),
        "max_por_dia": state.get("max_operacoes_dia"),
        "pendentes": len(pend),
    }

@app.post("/checar")
def checar_autonomia(data: dict):
    """Outros agentes chamam isso antes de agir"""
    score = data.get("score",0)
    valor = data.get("valor_usd",0)
    resultado = pode_agir_autonomo(score, valor)

    if not resultado["pode"] and valor > 0:
        # Adiciona como pendente para aprovacao
        op_id = adicionar_pendente({
            "descricao": data.get("descricao","operacao"),
            "valor": valor,
            "score": score,
            "tipo": data.get("tipo","geral"),
        })
        resultado["op_id"] = op_id
        resultado["pendente"] = True

    return resultado

@app.post("/pausar")
def pausar():
    state = ks()
    state["pausado"] = True
    salvar_ks(state)
    telegram("🛑 JARVIS PAUSADO via API")
    return {"ok": True, "pausado": True}

@app.post("/retomar")
def retomar():
    state = ks()
    state["pausado"] = False
    salvar_ks(state)
    telegram("✅ JARVIS RETOMADO via API")
    return {"ok": True, "pausado": False}

if __name__ == "__main__":
    print("[JARVIS Controller] :7813")
    print("Comandos Telegram: /pausar /retomar /status /sim /nao /limite /log")
    threading.Thread(target=monitor_telegram, daemon=True).start()
    threading.Thread(target=reset_diario, daemon=True).start()
    uvicorn.run(app, host="0.0.0.0", port=7813)
