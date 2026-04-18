#!/usr/bin/env python3
"""
JARVIS AIRDROP EXECUTOR :7800 (Grape Networks)
Execucao autonoma de airdrops — cadastro, conexao, execucao
Score >= 70 = age sozinho
Score < 70  = alerta Wagner para aprovacao
"""
import sys, os, json, time, datetime, requests, hashlib, threading, re
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Airdrop Executor v1")

TELEGRAM_TOKEN  = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID         = "170323936"
WALLET_ADDRESS  = os.getenv("JARVIS_WALLET_ADDRESS","")
WALLET_KEY      = os.getenv("JARVIS_WALLET_KEY","")
STATE_FILE      = "/Users/jarvis001/jarvis/data/executor_state.json"
THRESHOLD_AUTO  = 70  # Score >= 70 age sozinho

def telegram(msg: str, urgente: bool = False):
    if not TELEGRAM_TOKEN: return
    emoji = "🤖" if not urgente else "⚡"
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID,
                  "text": f"{emoji} JARVIS Executor\n\n{msg}",
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
        "executados": [],
        "aguardando_aprovacao": [],
        "convertidos": [],
        "total_executados": 0,
        "total_convertidos": 0
    }

def salvar_estado(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE,"w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

def criar_email_temp():
    """Cria email temporario via Guerrilla Mail API"""
    try:
        r = requests.get(
            "https://api.guerrillamail.com/ajax.php?f=get_email_address",
            timeout=10)
        data = r.json()
        email = data.get("email_addr","")
        sid = data.get("sid_token","")
        if email:
            return {"email": email, "sid": sid, "provider": "guerrillamail"}
    except: pass

    # Fallback: Temp Mail
    try:
        r = requests.get("https://www.1secmail.com/api/v1/?action=genRandomMailbox&count=1",
            timeout=10)
        emails = r.json()
        if emails:
            return {"email": emails[0], "sid": "", "provider": "1secmail"}
    except: pass

    # Fallback final: gera email baseado na wallet
    addr = WALLET_ADDRESS[-8:].lower() if WALLET_ADDRESS else "jarvis001"
    return {
        "email": f"jarvis.{addr}@proton.me",
        "sid": "",
        "provider": "manual"
    }

def verificar_email_confirmacao(email_data: dict, timeout_min: int = 5):
    """Aguarda email de confirmacao e retorna link"""
    if email_data.get("provider") != "guerrillamail":
        return None

    sid = email_data.get("sid","")
    deadline = time.time() + (timeout_min * 60)

    while time.time() < deadline:
        try:
            r = requests.get(
                f"https://api.guerrillamail.com/ajax.php?f=check_email&sid_token={sid}",
                timeout=10)
            emails = r.json().get("list",[])
            for email in emails:
                mail_id = email.get("mail_id")
                r2 = requests.get(
                    f"https://api.guerrillamail.com/ajax.php?f=fetch_email&email_id={mail_id}&sid_token={sid}",
                    timeout=10)
                body = r2.json().get("mail_body","")
                # Extrai link de confirmacao
                links = re.findall(r'https?://[^\s"<>]+confirm[^\s"<>]*', body)
                if links:
                    return links[0]
        except: pass
        time.sleep(15)
    return None

def executar_airdrop_zeroclaw(oportunidade: dict) -> dict:
    """Usa Zeroclaw gateway para executar airdrop via browser"""
    titulo = oportunidade.get("titulo","")
    link = oportunidade.get("link","")
    acao = oportunidade.get("analise",{}).get("acao_necessaria","")
    tipo = oportunidade.get("analise",{}).get("tipo","")

    resultado = {
        "op_id": oportunidade.get("id",""),
        "titulo": titulo[:60],
        "status": "tentando",
        "email_usado": "",
        "acao_realizada": "",
        "iniciado_em": datetime.datetime.now().isoformat()
    }

    try:
        # Cria email temporario
        email_data = criar_email_temp()
        resultado["email_usado"] = email_data.get("email","")

        # Tenta via Zeroclaw se disponivel
        zeroclaw_disponivel = False
        try:
            r = requests.get("http://localhost:42617/", timeout=3)
            zeroclaw_disponivel = r.status_code == 200
        except: pass

        if zeroclaw_disponivel and link:
            # Envia tarefa para Zeroclaw browser agent
            payload = {
                "task": f"""Acesse {link} e execute: {acao}
                Use email: {email_data.get('email','')}
                Use wallet: {WALLET_ADDRESS}
                Objetivo: participar do airdrop/testnet sem investimento""",
                "url": link
            }
            try:
                r = requests.post("http://localhost:42617/task",
                    json=payload, timeout=30)
                if r.status_code == 200:
                    resultado["status"] = "executado_zeroclaw"
                    resultado["acao_realizada"] = f"Zeroclaw: {acao[:80]}"
                else:
                    resultado["status"] = "zeroclaw_falhou"
            except:
                resultado["status"] = "zeroclaw_timeout"
        else:
            # Modo direto: registra para execucao manual assistida
            resultado["status"] = "pendente_browser"
            resultado["acao_realizada"] = f"Manual: {acao[:80]}"

        resultado["finalizado_em"] = datetime.datetime.now().isoformat()

    except Exception as e:
        resultado["status"] = "erro"
        resultado["erro"] = str(e)[:100]

    return resultado

def processar_oportunidades():
    """Pega oportunidades do Crypto Hunter e executa automaticamente"""
    state = carregar_estado()

    # Carrega oportunidades do hunter
    try:
        with open("/Users/jarvis001/jarvis/data/crypto_state.json") as f:
            crypto = json.load(f)
    except:
        return []

    ativas = crypto.get("oportunidades_ativas",[])
    ja_executados = {e.get("op_id","") for e in state.get("executados",[])}

    novas = []
    for op in ativas:
        op_id = op.get("id","")
        score = op.get("analise",{}).get("score",0)
        capital = op.get("analise",{}).get("requer_capital",True)

        if op_id in ja_executados:
            continue
        if capital:
            continue

        if score >= THRESHOLD_AUTO:
            # Age sozinho
            print(f"[Executor] AUTO: {op.get('titulo','')[:50]} (score {score})")
            resultado = executar_airdrop_zeroclaw(op)
            state.setdefault("executados",[]).append(resultado)
            state["total_executados"] = state.get("total_executados",0) + 1

            msg = (f"🤖 <b>EXECUTADO AUTOMATICAMENTE</b>\n\n"
                   f"<b>{op.get('titulo','')[:60]}</b>\n\n"
                   f"Score: {score}/100\n"
                   f"Email: {resultado.get('email_usado','')}\n"
                   f"Wallet: {WALLET_ADDRESS[:20]}...\n"
                   f"Status: {resultado.get('status','')}\n"
                   f"Ação: {resultado.get('acao_realizada','')[:80]}\n\n"
                   f"🔗 {op.get('link','')[:80]}")
            telegram(msg)
            novas.append(resultado)

        else:
            # Pede aprovacao
            state.setdefault("aguardando_aprovacao",[]).append({
                "op_id": op_id,
                "titulo": op.get("titulo","")[:60],
                "score": score,
                "link": op.get("link",""),
                "acao": op.get("analise",{}).get("acao_necessaria","")[:80]
            })
            msg = (f"⏳ <b>AGUARDA SUA APROVACAO</b>\n\n"
                   f"<b>{op.get('titulo','')[:60]}</b>\n\n"
                   f"Score: {score}/100 (abaixo de {THRESHOLD_AUTO})\n"
                   f"Ação: {op.get('analise',{}).get('acao_necessaria','')[:80]}\n\n"
                   f"Responda /aprovar_{op_id[:8]} para executar\n"
                   f"🔗 {op.get('link','')[:80]}")
            telegram(msg)

    salvar_estado(state)
    return novas

# API
@app.get("/")
def status():
    state = carregar_estado()
    return {
        "ok": True,
        "service": "airdrop-executor",
        "wallet": WALLET_ADDRESS,
        "threshold_auto": THRESHOLD_AUTO,
        "total_executados": state.get("total_executados",0),
        "total_convertidos": state.get("total_convertidos",0),
        "aguardando_aprovacao": len(state.get("aguardando_aprovacao",[])),
    }

@app.get("/executar")
def executar_manual():
    """Processa oportunidades agora"""
    resultados = processar_oportunidades()
    return {"ok": True, "executados": len(resultados), "detalhes": resultados[:5]}

@app.get("/pendentes")
def listar_pendentes():
    state = carregar_estado()
    return {"ok": True,
            "pendentes": state.get("aguardando_aprovacao",[])}

@app.post("/aprovar")
def aprovar(data: dict):
    """Wagner aprova execucao manual"""
    op_id = data.get("op_id","")
    state = carregar_estado()
    pendentes = state.get("aguardando_aprovacao",[])

    for p in pendentes:
        if p.get("op_id","").startswith(op_id):
            # Carrega oportunidade completa
            try:
                with open("/Users/jarvis001/jarvis/data/crypto_state.json") as f:
                    crypto = json.load(f)
                for op in crypto.get("oportunidades_ativas",[]):
                    if op.get("id","") == p["op_id"]:
                        resultado = executar_airdrop_zeroclaw(op)
                        state["executados"].append(resultado)
                        state["aguardando_aprovacao"] = [
                            x for x in pendentes if x["op_id"] != p["op_id"]]
                        state["total_executados"] = state.get("total_executados",0) + 1
                        salvar_estado(state)
                        telegram(f"✅ Aprovado e executado: {p['titulo']}")
                        return {"ok": True, "resultado": resultado}
            except Exception as e:
                return {"ok": False, "error": str(e)}

    return {"ok": False, "error": "nao encontrado"}

@app.post("/marcar_convertido")
def marcar_convertido(data: dict):
    """Marca airdrop como convertido — treina o sistema"""
    state = carregar_estado()
    op_id = data.get("op_id","")
    valor = data.get("valor_usd", 0)

    for ex in state.get("executados",[]):
        if ex.get("op_id","") == op_id:
            ex["convertido"] = True
            ex["valor_usd"] = valor
            ex["convertido_em"] = datetime.datetime.now().isoformat()
            state.setdefault("convertidos",[]).append(ex)
            state["total_convertidos"] = state.get("total_convertidos",0) + 1
            salvar_estado(state)
            telegram(f"💰 Airdrop convertido!\n{ex.get('titulo','')}\nValor: ${valor}")
            return {"ok": True}

    return {"ok": False}

def loop_background():
    def run():
        time.sleep(90)  # Aguarda hunter popular oportunidades
        while True:
            try:
                processar_oportunidades()
            except Exception as e:
                print(f"[Executor] Erro: {e}")
            time.sleep(3600)  # 1 hora
    threading.Thread(target=run, daemon=True).start()
    print("[Executor] Loop 1h iniciado")

if __name__ == "__main__":
    print(f"[JARVIS Airdrop Executor] :7800 iniciando...")
    print(f"Wallet: {WALLET_ADDRESS}")
    print(f"Threshold auto: score >= {THRESHOLD_AUTO}")
    loop_background()
    uvicorn.run(app, host="0.0.0.0", port=7810)
