#!/usr/bin/env python3
"""
SENTINEL :7792 — Agente de infraestrutura JARVIS
Auto-healing, balanceamento, anti-falso-positivo
"""
import sys, os, time, json, subprocess, threading
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="SENTINEL v1")

BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")

AGENTES = {
    "jarvis":     {"port": 7777, "launchctl": "com.jarvis.agent.server"},
    "network":    {"port": 7778, "launchctl": "com.jarvis.network.server"},
    "outlook":    {"port": 7779, "launchctl": "com.jarvis.outlook.server"},
    "odoo":       {"port": 7780, "launchctl": "com.jarvis.odoo.server"},
    "hunter":     {"port": 7781, "launchctl": "com.jarvis.hunter.server"},
    "auto":       {"port": 7782, "launchctl": "com.jarvis.auto.server"},
    "intel":      {"port": 7783, "launchctl": "com.jarvis.intel.server"},
    "prospect":   {"port": 7784, "launchctl": "com.jarvis.prospect.server"},
    "financial":  {"port": 7785, "launchctl": "com.jarvis.financial.server"},
    "contract":   {"port": 7786, "launchctl": "com.jarvis.contract.server"},
    "email":      {"port": 7787, "launchctl": "com.jarvis.email.server"},
    "agenda":     {"port": 7788, "launchctl": "com.jarvis.agenda.server"},
    "cobranca":   {"port": 7789, "launchctl": "com.jarvis.cobranca.server"},
    "relatorio":  {"port": 7790, "launchctl": "com.jarvis.relatorio.server"},
    "nps":        {"port": 7791, "launchctl": "com.jarvis.nps.server"},
}

SERVICOS_EXTERNOS = {
    "semantic_api": "http://192.168.8.124:5006/health",
    "hermes_shadow": "http://192.168.8.124:5009/health",
    "vision_ollama": "http://192.168.8.124:11434/api/tags",
}

status_cache = {}
falhas_consecutivas = {}
restart_count = {}

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def check_agente(nome, port):
    try:
        r = requests.get(f"http://localhost:{port}", timeout=3)
        return r.status_code == 200
    except:
        return False

def check_externo(nome, url):
    try:
        r = requests.get(url, timeout=5)
        return r.status_code == 200
    except:
        return False

def restart_agente(nome, launchctl):
    try:
        uid = subprocess.check_output(["id", "-u"]).decode().strip()
        subprocess.run(
            ["launchctl", "kickstart", "-k", f"gui/{uid}/{launchctl}"],
            capture_output=True, timeout=10
        )
        restart_count[nome] = restart_count.get(nome, 0) + 1
        return True
    except:
        return False

# Cooldown de restarts externos — evita spam
ultimo_restart_externo = {}

def restart_externo(nome):
    import time as _time
    agora = _time.time()
    ultimo = ultimo_restart_externo.get(nome, 0)
    # Cooldown de 10 minutos entre restarts do mesmo servico
    if agora - ultimo < 600:
        return False
    ultimo_restart_externo[nome] = agora
    
    if nome == "semantic_api":
        try:
            subprocess.run([
                "ssh", "-o", "StrictHostKeyChecking=no", "vision@192.168.8.124",
                "export PATH=/opt/homebrew/bin:$PATH && launchctl kickstart -k gui/$(id -u)/com.jarvis.vision.semantic 2>/dev/null"
            ], capture_output=True, timeout=15)
            return True
        except: return False
    if nome == "hermes_shadow":
        try:
            subprocess.run([
                "ssh", "-o", "StrictHostKeyChecking=no", "vision@192.168.8.124",
                "export PATH=/opt/homebrew/bin:$PATH && launchctl kickstart -k gui/$(id -u)/com.jarvis.hermes.shadow 2>/dev/null"
            ], capture_output=True, timeout=15)
            return True
        except: return False
    if nome == "vision_ollama":
        try:
            subprocess.run([
                "ssh", "-o", "StrictHostKeyChecking=no", "vision@192.168.8.124",
                "export PATH=/opt/homebrew/bin:$PATH && brew services restart ollama 2>/dev/null"
            ], capture_output=True, timeout=30)
            return True
        except: return False
    return False

def ciclo_vigilancia():
    while True:
        try:
            online = []
            offline = []

            # Verifica agentes locais
            for nome, cfg in AGENTES.items():
                ok = check_agente(nome, cfg["port"])
                # Anti-falso-positivo: confirma 2x antes de agir
                if not ok:
                    time.sleep(2)
                    ok = check_agente(nome, cfg["port"])

                if ok:
                    online.append(nome)
                    falhas_consecutivas[nome] = 0
                else:
                    falhas_consecutivas[nome] = falhas_consecutivas.get(nome, 0) + 1
                    offline.append(nome)

                    # Reinicia apos 2 falhas consecutivas confirmadas
                    if falhas_consecutivas[nome] >= 2:
                        restarts = restart_count.get(nome, 0)
                        if restarts < 5:  # Limite de 5 restarts por sessao
                            restarted = restart_agente(nome, cfg["launchctl"])
                            if restarted:
                                telegram(f"SENTINEL ativo: {nome} reiniciado automaticamente (tentativa {restarts+1})")
                            falhas_consecutivas[nome] = 0
                        else:
                            telegram(f"SENTINEL ALERTA: {nome} offline e nao responde apos {restarts} tentativas. Verificar manualmente.")

            # Verifica servicos externos
            for nome, url in SERVICOS_EXTERNOS.items():
                ok = check_externo(nome, url)
                if not ok:
                    time.sleep(3)
                    ok = check_externo(nome, url)
                if not ok:
                    falhas_consecutivas[nome] = falhas_consecutivas.get(nome, 0) + 1
                    if falhas_consecutivas[nome] >= 2:
                        restarted = restart_externo(nome)
                        if restarted:
                            # Alerta apenas se passou 1 hora desde o ultimo
                            chave_alerta = f"alerta_{nome}"
                            import time as _t
                            if _t.time() - alertas_enviados.get(chave_alerta, 0) > 3600:
                                telegram(f"SENTINEL: {nome} reiniciado automaticamente")
                                alertas_enviados[chave_alerta] = _t.time()
                        falhas_consecutivas[nome] = 0
                else:
                    falhas_consecutivas[nome] = 0

            # Atualiza cache
            status_cache["online"] = online
            status_cache["offline"] = offline
            status_cache["ts"] = time.strftime("%H:%M:%S")
            status_cache["restarts"] = dict(restart_count)

        except Exception as e:
            pass

        time.sleep(30)

@app.get("/")
def root():
    return {
        "ok": True,
        "service": "sentinel",
        "online": len(status_cache.get("online", [])),
        "offline": status_cache.get("offline", []),
        "restarts": status_cache.get("restarts", {}),
        "ts": status_cache.get("ts", "iniciando")
    }

@app.get("/health")
def health():
    return {"ok": True, "service": "sentinel"}

@app.get("/status")
def status():
    return status_cache

@app.post("/restart/{agente}")
def restart_manual(agente: str):
    if agente in AGENTES:
        ok = restart_agente(agente, AGENTES[agente]["launchctl"])
        return {"ok": ok, "agente": agente}
    return {"ok": False, "error": "agente nao encontrado"}

# Inicia thread de vigilancia
thread = threading.Thread(target=ciclo_vigilancia, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[SENTINEL] :7792 — vigilancia ativa")
    uvicorn.run(app, host="0.0.0.0", port=7792)
