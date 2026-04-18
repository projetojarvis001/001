#!/bin/bash
# Watcher Preditivo JARVIS — analisa tendencias e alertas
cd /Users/jarvis001/jarvis
python3 - << 'PYEOF'
import sys, requests, json, datetime
sys.path.insert(0,'/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')

BOT = "$(grep TELEGRAM_BOT_TOKEN .env | cut -d= -f2)"
CHAT = "170323936"

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=10)
    except: pass

# Status dos servicos
servicos = {"JARVIS":7777,"Sentinel":7792,"Security":7798,"Crypto":7799}
offline = []
for nome, porta in servicos.items():
    try:
        r = requests.get(f"http://localhost:{porta}", timeout=3)
        if r.status_code != 200:
            offline.append(nome)
    except:
        offline.append(nome)

if offline:
    notify(f"⚠️ JARVIS Watcher\nServicos OFFLINE: {', '.join(offline)}")

# Shadow stats
try:
    r = requests.get("http://192.168.8.124:5009/stats", timeout=5)
    stats = r.json()
    msg = (f"📊 JARVIS Watcher Preditivo\n"
           f"{datetime.datetime.now().strftime('%d/%m %H:%M')}\n\n"
           f"Shadow: {stats.get('total_interactions',0)} interacoes\n"
           f"Skills: {stats.get('skills_criadas',0)} autonomas\n"
           f"Offline: {len(offline)} servicos")
    notify(msg)
except: pass
PYEOF
