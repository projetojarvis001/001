#!/usr/bin/env python3

from pathlib import Path
import os

if os.getenv("TELEGRAM_ALERTS_ENABLED", "1") == "0" or Path("runtime/TELEGRAM_MUTE").exists():
    print("[MUTED] Telegram bloqueado por chave operacional")
    raise SystemExit(0)

import subprocess, json, re, urllib.request
from datetime import datetime

BOT = "8036971657:AAEGIF9BxetgE226XwQXTPYSwFvw4smX-_8"
CHAT = "170323936"

def notify(msg):
    try:
        data = json.dumps({"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}).encode()
        req = urllib.request.Request(f"https://api.telegram.org/bot{BOT}/sendMessage",
            data=data, headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=10)
    except: pass

def run(cmd): 
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.stdout.strip()

def http(url):
    try:
        r = urllib.request.urlopen(url, timeout=5)
        return str(r.status)
    except: return "000"

score = 100
issues = []
warns = []

mem_pages = run("vm_stat | grep 'Pages free' | awk '{print $3}' | tr -d '.'")
try: mem_mb = int(mem_pages) * 4096 // 1048576
except: mem_mb = 0

disk = run("df -h / | tail -1 | awk '{print $5}' | tr -d '%'")
try: disk_pct = int(disk)
except: disk_pct = 0

try: tunnel = open('/tmp/current_tunnel_mac1.txt').read().strip()
except: tunnel = ""

core = http("http://localhost:3000/health")
vision = http("http://192.168.8.124:5006/health")
n8n = http("http://localhost:5678/healthz")

pg_r = subprocess.run(['docker','exec','jarvis-postgres-1','pg_isready','-U','jarvis_admin','-d','jarvis_db'],
    capture_output=True, text=True)
pg = "1" if "accepting" in pg_r.stdout else "0"

redis_r = subprocess.run(['docker','exec','redis','redis-cli','-a','W!@#wps@2026','ping'],
    capture_output=True, text=True)
redis = "1" if "PONG" in redis_r.stdout else "0"

tg_r = urllib.request.urlopen(
    f"https://api.telegram.org/bot{BOT}/getMe", timeout=5)
telegram = "1" if tg_r.status == 200 else "0"

if mem_mb < 400: score -= 20; issues.append("HARDWARE: RAM critica " + str(mem_mb) + "MB")
elif mem_mb < 700: score -= 5; warns.append("HARDWARE: RAM baixa " + str(mem_mb) + "MB")
if disk_pct > 85: score -= 15; issues.append("HARDWARE: Disco " + str(disk_pct) + "%")
if not tunnel: score -= 10; issues.append("REDE: Tunnel offline")
if core != "200": score -= 25; issues.append("PLATAFORMA: jarvis-core offline")
if vision != "200": score -= 20; issues.append("PLATAFORMA: VISION offline")
if pg == "0": score -= 20; issues.append("BD: PostgreSQL offline")
if redis == "0": score -= 10; warns.append("MENSAGERIA: Redis offline")
if telegram == "0": score -= 15; issues.append("TELEGRAM: Bot inacessivel")
if n8n != "200": score -= 5; warns.append("N8N: offline")

if score < 0: score = 0
if score >= 90: status = "SAUDAVEL"
elif score >= 70: status = "ATENCAO"
elif score >= 50: status = "DEGRADADO"
else: status = "CRITICO"

report = {
    "ts": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "score": score, "status": status,
    "mem_mb": mem_mb, "disk_pct": disk_pct,
    "tunnel": tunnel, "core": core, "vision": vision,
    "postgres": pg, "redis": redis, "telegram": telegram, "n8n": n8n,
    "issues": "|".join(issues),
    "warnings": "|".join(warns)
}

for path in ['/tmp/health_report.json',
             '/Users/jarvis001/jarvis/core/dashboard/health_report.json',
             '/Users/jarvis001/jarvis/dashboard/health_report.json']:
    with open(path, 'w') as f:
        json.dump(report, f, ensure_ascii=True)

print(f"[{datetime.now().strftime('%a %d %b %Y %H:%M:%S')}] Health score: {score}/100 — {status}")

if score < 90:
    msg = f"Health Report JARVIS\n{datetime.now().strftime('%d/%m/%Y %H:%M')}\nScore: {score}/100 — {status}\n\n"
    if issues: msg += "\n".join(issues) + "\n"
    if warns: msg += "\n".join(warns)
    notify(msg)
