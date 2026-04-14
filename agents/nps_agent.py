#!/usr/bin/env python3
"""
JARVIS NPS Agent — Pesquisa automatica de satisfacao
Trigger: !nps [cliente] ou automatico D+30 e D+90 apos instalacao
"""
import sys, os, warnings, json, requests
from datetime import datetime
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

try:
    from cost_router import ask
except:
    from langchain_groq import ChatGroq
    from langchain_core.messages import HumanMessage
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0)
    def ask(q, system="", **kwargs):
        return {"ok": True, "content": _llm.invoke([HumanMessage(content=q)]).content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")
NPS_FILE = "/Users/jarvis001/jarvis/data/nps_respostas.json"

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def load_nps():
    try:
        os.makedirs(os.path.dirname(NPS_FILE), exist_ok=True)
        with open(NPS_FILE) as f:
            return json.load(f)
    except: return []

def save_nps(data):
    os.makedirs(os.path.dirname(NPS_FILE), exist_ok=True)
    with open(NPS_FILE, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def enviar_pesquisa_nps(cliente: str, tipo: str = "pos_instalacao") -> str:
    templates = {
        "pos_instalacao": f"""Pesquisa NPS WPS Digital — {cliente}

Em uma escala de 0 a 10, qual a probabilidade de voce recomendar a WPS Digital para outro sindico?

0-6: Detrator
7-8: Neutro
9-10: Promotor

Responda com: NPS_{cliente[:8].upper().replace(' ','_')}_[sua_nota]
Ex: NPS_JARDINS_9

Sua opiniao e muito importante para nos!
WPS Digital — 25 anos em seguranca condominial""",
        "trimestral": f"""Pesquisa Trimestral WPS Digital — {cliente}

Como avalia o servico WPS Digital nos ultimos 3 meses?

1. Qualidade do suporte (0-10)
2. Tempo de resposta (0-10)
3. Qualidade das cameras (0-10)
4. Recomendaria para outros? (0-10)

Responda: NPS_Q_{cliente[:8].upper().replace(' ','_')}_[nota1]_[nota2]_[nota3]_[nota4]"""
    }
    
    msg = templates.get(tipo, templates["pos_instalacao"])
    notify(msg)
    
    # Registra envio
    nps_data = load_nps()
    nps_data.append({
        "cliente": cliente,
        "tipo": tipo,
        "enviado_em": datetime.now().strftime("%d/%m/%Y %H:%M"),
        "status": "enviado",
        "nota": None
    })
    save_nps(nps_data)
    
    return f"Pesquisa NPS enviada para: {cliente}"

def processar_resposta_nps(texto: str) -> bool:
    texto = texto.strip().upper()
    if not texto.startswith("NPS_"):
        return False
    
    partes = texto.split("_")
    nps_data = load_nps()
    
    try:
        if "Q_" in texto:
            # Trimestral
            cliente_code = partes[2]
            notas = [int(p) for p in partes[3:7] if p.isdigit()]
            media = sum(notas) / len(notas) if notas else 0
            
            for item in nps_data:
                if cliente_code in item["cliente"].upper().replace(" ","_"):
                    item["nota"] = media
                    item["status"] = "respondido"
                    item["notas_detalhadas"] = notas
                    break
            
            emoji = "🟢" if media >= 9 else "🟡" if media >= 7 else "🔴"
            notify(f"{emoji} NPS Trimestral: {cliente_code}\nMedia: {media:.1f}/10\nNotas: {notas}")
        else:
            # Simples
            cliente_code = partes[1]
            nota = int(partes[2]) if len(partes) > 2 and partes[2].isdigit() else 0
            
            for item in nps_data:
                if cliente_code in item["cliente"].upper().replace(" ","_"):
                    item["nota"] = nota
                    item["status"] = "respondido"
                    break
            
            categoria = "Promotor" if nota >= 9 else "Neutro" if nota >= 7 else "Detrator"
            emoji = "🟢" if nota >= 9 else "🟡" if nota >= 7 else "🔴"
            notify(f"{emoji} NPS recebido: {cliente_code}\nNota: {nota}/10 — {categoria}")
            
            if nota <= 6:
                notify(f"ATENCAO: Cliente detrator {cliente_code} nota {nota}. Ligar hoje para Wagner investigar motivo.")
        
        save_nps(nps_data)
        return True
    except:
        return False

def relatorio_nps() -> str:
    nps_data = load_nps()
    respondidos = [n for n in nps_data if n.get("nota") is not None]
    
    if not respondidos:
        return "Nenhuma resposta NPS ainda."
    
    notas = [n["nota"] for n in respondidos]
    media = sum(notas) / len(notas)
    promotores = sum(1 for n in notas if n >= 9)
    neutros = sum(1 for n in notas if 7 <= n < 9)
    detratores = sum(1 for n in notas if n < 7)
    nps_score = ((promotores - detratores) / len(notas)) * 100
    
    relatorio = f"""NPS WPS Digital — Relatorio
Total respostas: {len(respondidos)}
Media: {media:.1f}/10
NPS Score: {nps_score:.0f}
Promotores: {promotores} ({promotores*100//len(notas)}%)
Neutros: {neutros} ({neutros*100//len(notas)}%)
Detratores: {detratores} ({detratores*100//len(notas)}%)"""
    
    notify(relatorio)
    return relatorio

def run(query: str) -> str:
    q = query.strip().upper()
    if q.startswith("NPS_"):
        ok = processar_resposta_nps(query)
        return "Resposta NPS processada." if ok else "Formato invalido."
    elif any(w in query.lower() for w in ["relatorio","report","score","resultado"]):
        return relatorio_nps()
    else:
        return enviar_pesquisa_nps(query)

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Condominio Jardins"
    print(run(q))
