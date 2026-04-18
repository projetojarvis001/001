#!/usr/bin/env python3
"""
JARVIS SECURITY AGENT :7798
Zero Intrusion Monitor — monitora 4 servidores e alerta no Telegram
Roda a cada 5 minutos, detecta anomalias e intrusões em tempo real
"""
import sys, os, subprocess, time, requests, json, datetime, hashlib
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="JARVIS Security Agent v1")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT_ID        = os.getenv("TELEGRAM_CHAT_ID","170323936")
STATE_FILE     = "/Users/jarvis001/jarvis/data/security_state.json"

# IPs e usuarios AUTORIZADOS
IPS_AUTORIZADOS = {
    "192.168.8.121": "JARVIS",
    "192.168.8.124": "VISION",
    "192.168.8.36":  "FRIDAY",
    "192.168.8.86":  "rede_interna",
    "192.168.8.100": "rede_interna",
    "192.168.8.102": "dispositivo_temp",
    "192.168.8.111": "rede_interna",
    "186.209.45.40": "engenheiro_grape",
    "179.246.142.67": "acesso_autorizado",
    "100.67.82.123":  "tailscale_tadash",
    "100.118.208.78": "tailscale_friday",
    "100.66.31.34":   "tailscale_vision",
    "127.0.0.1":      "localhost",
}

USUARIOS_AUTORIZADOS = ["wps","wagner","vision","jarvis001","grape","root","postgres","reboot","shutdown","_mbsetupuser","daemon","nobody"]

def telegram(msg: str, urgente: bool = False):
    if not TELEGRAM_TOKEN:
        return
    emoji = "🚨" if urgente else "🔐"
    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": CHAT_ID,
                  "text": f"{emoji} JARVIS Security\n\n{msg}",
                  "parse_mode": "HTML"},
            timeout=10)
    except: pass

def carregar_estado():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as f:
                return json.load(f)
    except: pass
    return {"logins_vistos": {}, "alertas_enviados": [], "ultimo_check": ""}

def salvar_estado(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE,"w") as f:
        json.dump(state, f, indent=2)

def ssh_run(host, user, cmd, porta=22, senha=None):
    try:
        if senha:
            result = subprocess.run(
                ["sshpass","-p",senha,"ssh",
                 "-o","StrictHostKeyChecking=no",
                 "-o","ConnectTimeout=10",
                 f"-p{porta}", f"{user}@{host}", cmd],
                capture_output=True, text=True, timeout=20)
        else:
            result = subprocess.run(
                ["ssh","-o","StrictHostKeyChecking=no",
                 "-o","ConnectTimeout=10",
                 f"-p{porta}", f"{user}@{host}", cmd],
                capture_output=True, text=True, timeout=20)
        return result.stdout.strip()
    except Exception as e:
        return f"ERRO: {e}"

def verificar_logins_novos(server_name, logins_raw, state):
    """Detecta logins novos comparando com estado anterior"""
    alertas = []
    linhas = [l.strip() for l in logins_raw.split('\n') if l.strip() and 'wtmp' not in l]

    for linha in linhas[:10]:
        partes = linha.split()
        if len(partes) < 3:
            continue

        usuario = partes[0]
        ip_origem = ""
        for p in partes:
            if '.' in p and p.count('.') == 3 and not p.startswith('0'):
                ip_origem = p
                break

        chave = hashlib.md5(linha.encode()).hexdigest()[:12]

        # Login novo nao visto antes
        if chave not in state.get("logins_vistos",{}):
            state.setdefault("logins_vistos",{})[chave] = {
                "servidor": server_name,
                "linha": linha,
                "visto_em": datetime.datetime.now().isoformat()
            }

            # Verifica se e suspeito
            usuario_suspeito = usuario not in USUARIOS_AUTORIZADOS
            ip_suspeito = ip_origem and ip_origem not in IPS_AUTORIZADOS

            if usuario_suspeito or ip_suspeito:
                alertas.append({
                    "servidor": server_name,
                    "usuario": usuario,
                    "ip": ip_origem,
                    "linha": linha,
                    "tipo": "usuario_desconhecido" if usuario_suspeito else "ip_desconhecido"
                })

    return alertas

def verificar_conexoes_externas(server_name, conexoes_raw):
    """Detecta conexoes para IPs externos nao autorizados"""
    alertas = []
    for linha in conexoes_raw.split('\n'):
        if 'ESTABLISHED' not in linha:
            continue
        # Extrai IP remoto
        partes = linha.split()
        for p in partes:
            if '.' in p and ':' in p:
                ip = p.split(':')[0].split('.')
                if len(ip) == 4:
                    ip_str = '.'.join(ip)
                    # Ignora IPs privados e autorizados
                    if (not ip_str.startswith('192.168') and
                        not ip_str.startswith('10.') and
                        not ip_str.startswith('127.') and
                        not ip_str.startswith('100.') and
                        ip_str not in IPS_AUTORIZADOS):
                        alertas.append({
                            "servidor": server_name,
                            "ip": ip_str,
                            "conexao": linha.strip(),
                            "tipo": "conexao_externa_suspeita"
                        })
    return alertas

def verificar_cpu_alta(server_name, cpu_raw):
    """Detecta CPU anormalmente alta (possivel mineracao ou ataque)"""
    alertas = []
    try:
        linhas = cpu_raw.strip().split('\n')
        for linha in linhas[1:6]:  # top 5 processos
            partes = linha.split()
            if len(partes) > 2:
                try:
                    cpu = float(partes[2])
                    proc = ' '.join(partes[10:])
                    if cpu > 80:
                        alertas.append({
                            "servidor": server_name,
                            "cpu": cpu,
                            "processo": proc[:60],
                            "tipo": "cpu_alta_suspeita"
                        })
                except: pass
    except: pass
    return alertas

def verificar_processos_suspeitos(server_name, procs_raw):
    """Detecta processos de mineracao ou malware"""
    palavras_suspeitas = [
        "xmrig","minerd","cpuminer","bfgminer","cgminer",
        "nicehash","coinhive","cryptonight","stratum",
        "ncat","netcat","nc -l","socat","reverse_shell",
        "wget http\|curl http.*sh\|bash -i",
        "base64 -d\|python -c\|perl -e\|ruby -e"
    ]
    alertas = []
    procs_lower = procs_raw.lower()
    for palavra in palavras_suspeitas:
        if palavra.replace("\\|","").replace(".*","") in procs_lower:
            alertas.append({
                "servidor": server_name,
                "palavra": palavra,
                "tipo": "processo_malicioso"
            })
    return alertas

def check_jarvis():
    """Verifica JARVIS local"""
    alertas = []
    state = carregar_estado()

    # Logins
    logins = subprocess.run(["last"], capture_output=True, text=True).stdout
    alertas += verificar_logins_novos("JARVIS:121", logins, state)

    # Conexoes externas
    conex = subprocess.run(["netstat","-an"], capture_output=True, text=True).stdout
    alertas += verificar_conexoes_externas("JARVIS:121", conex)

    # CPU
    cpu = subprocess.run(["ps","aux","--sort=-pcpu" if False else "-r","-r"],
        capture_output=True, text=True).stdout
    alertas += verificar_cpu_alta("JARVIS:121", cpu)

    salvar_estado(state)
    return alertas

def check_vision():
    """Verifica VISION"""
    alertas = []
    state = carregar_estado()

    logins = ssh_run("192.168.8.124","vision","last | head -15")
    alertas += verificar_logins_novos("VISION:124", logins, state)

    conex = ssh_run("192.168.8.124","vision",
        "netstat -an 2>/dev/null | grep ESTABLISHED")
    alertas += verificar_conexoes_externas("VISION:124", conex)

    cpu = ssh_run("192.168.8.124","vision",
        "ps aux | sort -rn -k 3 | head -6")
    alertas += verificar_cpu_alta("VISION:124", cpu)

    procs = ssh_run("192.168.8.124","vision","ps aux")
    alertas += verificar_processos_suspeitos("VISION:124", procs)

    salvar_estado(state)
    return alertas

def check_friday():
    """Verifica FRIDAY"""
    alertas = []
    state = carregar_estado()

    logins = ssh_run("192.168.8.36","wagner",
        "last | head -15", senha="04475475")
    alertas += verificar_logins_novos("FRIDAY:36", logins, state)

    falhas = ssh_run("192.168.8.36","wagner",
        "journalctl -u ssh --since '1 hour ago' 2>/dev/null | grep -i 'fail\|invalid' | wc -l",
        senha="04475475")
    try:
        n_falhas = int(falhas.strip())
        if n_falhas > 10:
            alertas.append({
                "servidor": "FRIDAY:36",
                "tentativas": n_falhas,
                "tipo": "brute_force_ssh"
            })
    except: pass

    procs = ssh_run("192.168.8.36","wagner","ps aux", senha="04475475")
    alertas += verificar_processos_suspeitos("FRIDAY:36", procs)

    salvar_estado(state)
    return alertas

def check_tadash():
    """Verifica TADASH"""
    alertas = []
    state = carregar_estado()

    logins = ssh_run("177.104.176.69","wps",
        "last | head -15", porta=61022, senha="12qwaszx")
    alertas += verificar_logins_novos("TADASH:VPS", logins, state)

    falhas = ssh_run("177.104.176.69","wps",
        "journalctl -u ssh --since '1 hour ago' 2>/dev/null | grep -i 'fail\|invalid' | wc -l",
        porta=61022, senha="12qwaszx")
    try:
        n_falhas = int(falhas.strip())
        if n_falhas > 5:
            alertas.append({
                "servidor": "TADASH:VPS",
                "tentativas": n_falhas,
                "tipo": "brute_force_ssh"
            })
    except: pass

    procs = ssh_run("177.104.176.69","wps",
        "ps aux | sort -rn -k 3 | head -10",
        porta=61022, senha="12qwaszx")
    alertas += verificar_cpu_alta("TADASH:VPS", procs)

    salvar_estado(state)
    return alertas

def ciclo_seguranca():
    """Ciclo principal — roda a cada 5 minutos"""
    print(f"[Security] Ciclo iniciado: {datetime.datetime.now()}")
    state = carregar_estado()

    todos_alertas = []
    todos_alertas += check_jarvis()
    todos_alertas += check_vision()
    todos_alertas += check_friday()
    todos_alertas += check_tadash()

    # Filtra alertas ja enviados
    alertas_novos = []
    for alerta in todos_alertas:
        chave = hashlib.md5(json.dumps(alerta, sort_keys=True).encode()).hexdigest()[:12]
        if chave not in state.get("alertas_enviados",[]):
            state.setdefault("alertas_enviados",[]).append(chave)
            alertas_novos.append(alerta)

    # Limita lista de alertas enviados (max 500)
    if len(state["alertas_enviados"]) > 500:
        state["alertas_enviados"] = state["alertas_enviados"][-200:]

    state["ultimo_check"] = datetime.datetime.now().isoformat()
    salvar_estado(state)

    if alertas_novos:
        for alerta in alertas_novos:
            tipo = alerta.get("tipo","?")
            servidor = alerta.get("servidor","?")

            if tipo == "brute_force_ssh":
                msg = (f"<b>BRUTE FORCE SSH</b>\n"
                       f"Servidor: {servidor}\n"
                       f"Tentativas: {alerta.get('tentativas',0)} na ultima hora\n"
                       f"Acao: verificar origem")
                telegram(msg, urgente=True)

            elif tipo == "usuario_desconhecido":
                msg = (f"<b>LOGIN USUARIO DESCONHECIDO</b>\n"
                       f"Servidor: {servidor}\n"
                       f"Usuario: {alerta.get('usuario','?')}\n"
                       f"IP: {alerta.get('ip','local')}\n"
                       f"Log: {alerta.get('linha','?')[:80]}")
                telegram(msg, urgente=True)

            elif tipo == "ip_desconhecido":
                msg = (f"<b>LOGIN DE IP NAO AUTORIZADO</b>\n"
                       f"Servidor: {servidor}\n"
                       f"IP: {alerta.get('ip','?')}\n"
                       f"Log: {alerta.get('linha','?')[:80]}")
                telegram(msg, urgente=True)

            elif tipo == "conexao_externa_suspeita":
                msg = (f"<b>CONEXAO EXTERNA SUSPEITA</b>\n"
                       f"Servidor: {servidor}\n"
                       f"IP: {alerta.get('ip','?')}\n"
                       f"Detalhe: {alerta.get('conexao','?')[:80]}")
                telegram(msg, urgente=True)

            elif tipo == "processo_malicioso":
                msg = (f"<b>PROCESSO SUSPEITO DETECTADO</b>\n"
                       f"Servidor: {servidor}\n"
                       f"Palavra-chave: {alerta.get('palavra','?')}\n"
                       f"Acao: verificar imediatamente")
                telegram(msg, urgente=True)

            elif tipo == "cpu_alta_suspeita":
                msg = (f"<b>CPU ALTA SUSPEITA</b>\n"
                       f"Servidor: {servidor}\n"
                       f"CPU: {alerta.get('cpu',0):.1f}%\n"
                       f"Processo: {alerta.get('processo','?')}")
                telegram(msg, urgente=False)

        print(f"[Security] {len(alertas_novos)} alertas enviados")
    else:
        print(f"[Security] Sistema limpo — sem anomalias")

    return alertas_novos

# API endpoints
@app.get("/")
def status():
    state = carregar_estado()
    return {
        "ok": True,
        "service": "security-agent",
        "ultimo_check": state.get("ultimo_check","nunca"),
        "alertas_historico": len(state.get("alertas_enviados",[]))
    }

@app.get("/scan")
def scan_manual():
    """Dispara scan manual"""
    alertas = ciclo_seguranca()
    return {"ok": True, "alertas": len(alertas), "detalhes": alertas}

@app.get("/status_servidores")
def status_servidores():
    """Status rapido dos 4 servidores"""
    import socket
    servidores = {
        "JARVIS:121":  ("192.168.8.121", 22),
        "VISION:124":  ("192.168.8.124", 22),
        "FRIDAY:36":   ("192.168.8.36",  22),
        "TADASH:VPS":  ("177.104.176.69", 61022),
    }
    resultado = {}
    for nome, (ip, porta) in servidores.items():
        try:
            s = socket.socket()
            s.settimeout(3)
            ok = s.connect_ex((ip, porta)) == 0
            s.close()
            resultado[nome] = "online" if ok else "offline"
        except:
            resultado[nome] = "offline"
    return {"ok": True, "servidores": resultado}

@app.post("/autorizar_ip")
def autorizar_ip(data: dict):
    """Adiciona IP autorizado em tempo real"""
    ip = data.get("ip","")
    descricao = data.get("descricao","manual")
    if ip:
        IPS_AUTORIZADOS[ip] = descricao
        return {"ok": True, "ip": ip, "descricao": descricao}
    return {"ok": False, "error": "ip obrigatorio"}

def loop_background():
    """Loop de monitoramento em background"""
    import threading
    def run():
        # Aguarda 30s antes do primeiro scan (deixa servicos subirem)
        time.sleep(30)
        while True:
            try:
                ciclo_seguranca()
            except Exception as e:
                print(f"[Security] Erro no ciclo: {e}")
            time.sleep(300)  # 5 minutos
    t = threading.Thread(target=run, daemon=True)
    t.start()
    print("[Security] Monitor background iniciado (ciclo 5min)")

if __name__ == "__main__":
    print("[JARVIS Security Agent] :7798 iniciando...")
    print("Monitorando: JARVIS + VISION + FRIDAY + TADASH")
    print("Alertas: Telegram em tempo real")
    loop_background()
    uvicorn.run(app, host="0.0.0.0", port=7798)
