#!/usr/bin/env python3
import sys, os, warnings, json, subprocess, requests
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
try:
    from jarvis_context import SYSTEM_PROMPT_AUTO
except:
    SYSTEM_PROMPT_AUTO = "Voce e o planejador do JARVIS. Gere planos em JSON."
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage

load_dotenv("/Users/jarvis001/jarvis/.env")
llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0.1)
BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

BLOCKED = ["rm -rf /", "mkfs", "dd if=", "DROP TABLE", "DROP DATABASE", "shutdown", "reboot"]

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def safe(cmd):
    return not any(b.lower() in cmd.lower() for b in BLOCKED)

def run_cmd(cmd, host=None, timeout=30):
    if not safe(cmd):
        return {"ok": False, "stdout": "", "stderr": "BLOQUEADO: comando proibido"}
    if host:
        cmd = f'ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 {host} "{cmd}"'
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, cwd="/Users/jarvis001/jarvis")
        return {"ok": r.returncode==0, "stdout": r.stdout[:800], "stderr": r.stderr[:300], "rc": r.returncode}
    except Exception as e:
        return {"ok": False, "stdout": "", "stderr": str(e), "rc": -1}

def get_state():
    state = {}
    r = run_cmd("docker ps --format '{{.Names}}: {{.Status}}' | head -6")
    state["containers"] = r["stdout"].strip()
    agents = {}
    for port in [7777,7778,7779,7780,7781]:
        try:
            resp = requests.get(f"http://localhost:{port}", timeout=3)
            agents[str(port)] = resp.json().get("service","ok")
        except:
            agents[str(port)] = "OFFLINE"
    state["agents"] = agents
    try:
        state["core"] = "OK" if requests.get("http://localhost:3000/health",timeout=5).json().get("ok") else "FAIL"
    except:
        state["core"] = "OFFLINE"
    return state

def make_plan(objective, state):
    prompt = json.dumps({"objetivo": objective, "estado": state}, ensure_ascii=False)
    resp = llm.invoke([
        SystemMessage(content='''Voce e o planejador do JARVIS. Gere um plano em JSON.
Regras: max 5 comandos, bash simples e seguro, nunca use rm -rf / mkfs shutdown reboot.
target pode ser: local (Mac Mini JARVIS), tadash (ssh wps@100.67.82.123), friday (ssh wagner@192.168.8.36).
Formato EXATO:
{"objetivo":"texto","plano":[{"passo":1,"descricao":"texto","comando":"bash cmd","target":"local"}],"criterio":"texto"}'''),
        HumanMessage(content=prompt)
    ])
    try:
        text = resp.content.strip()
        if "```" in text:
            text = text.split("```")[1].replace("json","").strip()
        return json.loads(text)
    except:
        return None

# Mapa de palavras-chave por nivel de risco
RISK_KEYWORDS = {
    5: ["drop table", "delete", "rm -rf", "format", "wipe", "permanent"],
    4: ["n8n", "workflow", "database", "banco de dados", "credencial", "senha"],
    3: ["config", "configuracao", "agente", "agent", "email", "enviar", "alterar"],
}

def classify_risk(objective: str, cmd: str = "") -> int:
    text = (objective + " " + cmd).lower()
    for nivel in [5, 4, 3]:
        if any(kw in text for kw in RISK_KEYWORDS[nivel]):
            return nivel
    return 1

def run_auto(objective):
    print(f"[Auto] Objetivo: {objective[:80]}")
    notify(f"JARVIS Autonomo iniciado\nObjetivo: {objective[:200]}")
    
    state = get_state()
    plan = make_plan(objective, state)
    
    if not plan:
        notify("Nao consegui gerar plano.")
        return "Falha no planejamento"
    
    steps = plan.get("plano", [])[:5]
    notify(f"Plano: {len(steps)} passos")
    
    results = []
    for step in steps:
        passo = step.get("passo","?")
        desc = step.get("descricao","?")
        cmd = step.get("comando","")
        target = step.get("target","local")
        
        print(f"[Auto] Passo {passo}: {desc[:60]}")
        notify(f"Passo {passo}: {desc[:80]}")
        
        host = None
        if target == "tadash": host = "wps@100.67.82.123"
        elif target == "friday": host = "wagner@192.168.8.36"
        
        result = run_cmd(cmd, host)
        results.append({"passo": passo, "ok": result["ok"], "out": result["stdout"][:200], "err": result["stderr"][:100]})
        print(f"[Auto] {'OK' if result['ok'] else 'ERRO'}: {result['stdout'][:60]}")
    
    ok = sum(1 for r in results if r["ok"])
    total = len(results)
    
    summary_resp = llm.invoke([
        SystemMessage(content="Resuma em 3 linhas o que foi feito e o resultado final em portugues."),
        HumanMessage(content=f"Objetivo: {objective}\nResultados: {json.dumps(results, ensure_ascii=False)}")
    ])
    
    emoji = "OK" if ok==total else "PARCIAL" if ok>0 else "FALHA"
    report = f"Agente Autonomo JARVIS\n{emoji}: {ok}/{total} passos\n\n{summary_resp.content}"
    notify(report)
    print(f"[Auto] Concluido {ok}/{total}")
    return report

if __name__ == "__main__":
    obj = " ".join(sys.argv[1:]) if len(sys.argv)>1 else "verifique o status de todos os servicos"
    print(run_auto(obj))
