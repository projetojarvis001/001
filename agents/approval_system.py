#!/usr/bin/env python3
"""
Sistema de Aprovacao JARVIS
Wagner aprova ou veta acoes de nivel 3+ via Telegram
"""
import sys, os, warnings, json, requests, time, threading
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

# Fila de aprovacoes pendentes
_pending = {}

NIVEL_LABELS = {
    1: "AUTO — executa sozinho",
    2: "AUTO — executa sozinho",
    3: "APROVACAO — impacto moderado",
    4: "APROVACAO — impacto alto",
    5: "APROVACAO CRITICA — irreversivel",
}

def send_approval_request(action_id: str, descricao: str, nivel: int, 
                           comando: str = "", timeout_min: int = 10) -> bool:
    """
    Envia pedido de aprovacao no Telegram e aguarda resposta.
    Nivel 1-2: executa automaticamente
    Nivel 3-5: aguarda SIM/NAO
    Retorna True se aprovado, False se rejeitado/timeout
    """
    if nivel <= 2:
        notify(f"AUTO [{nivel}] Executando: {descricao[:100]}")
        return True
    
    label = NIVEL_LABELS.get(nivel, "APROVACAO")
    emoji = "⚠️" if nivel == 3 else "🚨" if nivel == 4 else "🔴"
    
    msg = f"""{emoji} *JARVIS — Pedido de Aprovacao*

*Nivel {nivel}:* {label}
*Acao:* {descricao}
{f'*Comando:* `{comando[:100]}`' if comando else ''}

Responda com:
*SIM_{action_id}* para aprovar
*NAO_{action_id}* para rejeitar

Timeout: {timeout_min} minutos"""
    
    notify(msg)
    
    # Registra na fila
    _pending[action_id] = {"status": "pending", "nivel": nivel}
    
    # Aguarda resposta via polling
    deadline = time.time() + (timeout_min * 60)
    while time.time() < deadline:
        if _pending.get(action_id, {}).get("status") != "pending":
            result = _pending.pop(action_id, {}).get("status") == "approved"
            return result
        time.sleep(5)
    
    # Timeout
    _pending.pop(action_id, None)
    notify(f"⏰ Timeout — acao cancelada: {descricao[:80]}")
    return False

def process_approval_response(text: str) -> bool:
    """Processa resposta SIM_xxx ou NAO_xxx do Telegram"""
    text = text.strip().upper()
    if text.startswith("SIM_"):
        action_id = text[4:]
        if action_id in _pending:
            _pending[action_id]["status"] = "approved"
            notify(f"✅ Aprovado: {action_id}")
            return True
    elif text.startswith("NAO_"):
        action_id = text[4:]
        if action_id in _pending:
            _pending[action_id]["status"] = "rejected"
            notify(f"❌ Rejeitado: {action_id}")
            return True
    return False

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def request_action(descricao: str, nivel: int, comando: str = "", 
                   execute_fn=None, timeout_min: int = 10):
    """
    Interface principal — solicita aprovacao e executa se aprovado
    
    Uso:
        from approval_system import request_action
        result = request_action(
            descricao="Alterar configuracao do agente jarvis",
            nivel=3,
            comando="sed -i 's/old/new/' agents/jarvis_agent.py",
            execute_fn=lambda: os.system("sed -i 's/old/new/' agents/jarvis_agent.py")
        )
    """
    import uuid
    action_id = str(uuid.uuid4())[:8].upper()
    
    approved = send_approval_request(action_id, descricao, nivel, comando, timeout_min)
    
    if approved and execute_fn:
        try:
            result = execute_fn()
            notify(f"✅ Executado com sucesso: {descricao[:80]}")
            return {"ok": True, "result": result}
        except Exception as e:
            notify(f"❌ Erro na execucao: {str(e)[:100]}")
            return {"ok": False, "error": str(e)}
    elif not approved:
        return {"ok": False, "error": "rejeitado ou timeout"}
    
    return {"ok": True, "result": None}

if __name__ == "__main__":
    # Teste
    print("Testando sistema de aprovacao...")
    print("Nivel 1 (auto):", send_approval_request("TEST01", "Reiniciar container", 1))
    print("Sistema OK — aguardando integracao")
