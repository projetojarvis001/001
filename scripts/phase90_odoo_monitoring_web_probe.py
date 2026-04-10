#!/usr/bin/env python3
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
import os

BASE = Path("logs/executive")
DOCS = Path("docs/generated")
BASE.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
out_json = BASE / f"phase90_odoo_monitoring_web_probe_{ts}.json"
out_md = DOCS / f"phase90_odoo_monitoring_web_probe_{ts}.md"

target = os.environ["ODOO_URL"].rstrip("/") + "/web/login"
http_ok = False
login_page_ok = False
status_code = 0
server_header = ""
error = ""

try:
    req = urllib.request.Request(target, method="GET")
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read().decode("utf-8", errors="ignore")
        status_code = getattr(resp, "status", 200)
        server_header = resp.headers.get("Server", "")
        http_ok = 200 <= status_code < 400
        login_page_ok = ("login" in body.lower()) or ("odoo" in body.lower())
except Exception as e:
    error = str(e)

payload = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "web_probe": {
        "target": target,
        "http_ok": http_ok,
        "login_page_ok": login_page_ok,
        "status_code": status_code,
        "server_header": server_header,
        "error": error
    },
    "governance": {
        "deploy_executed": False,
        "production_changed": False
    }
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
out_md.write_text(
f"""# FASE 90 — ODOO Monitoring Web Probe

## Probe
- target: {target}
- http_ok: {http_ok}
- login_page_ok: {login_page_ok}
- status_code: {status_code}
- server_header: {server_header}
- error: {error}

## Governança
- deploy_executed: false
- production_changed: false
"""
)

print(f"[OK] monitoring web probe gerado em {out_json}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
