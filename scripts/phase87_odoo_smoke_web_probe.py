#!/usr/bin/env python3
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

BASE = Path("logs/executive")
DOCS = Path("docs/generated")
BASE.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
out_json = BASE / f"phase87_odoo_smoke_web_probe_{ts}.json"
out_md = DOCS / f"phase87_odoo_smoke_web_probe_{ts}.md"

url = os.environ["ODOO_URL"].rstrip("/")
target = f"{url}/web/login"

http_ok = False
login_page_ok = False
status_code = 0
server_header = ""
error = ""

try:
    req = Request(target, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req, timeout=20) as resp:
        status_code = getattr(resp, "status", 200)
        server_header = resp.headers.get("Server", "")
        body = resp.read(4096).decode("utf-8", errors="ignore")
        http_ok = 200 <= status_code < 400
        login_page_ok = ("login" in body.lower()) or ("odoo" in body.lower())
except HTTPError as e:
    status_code = e.code
    server_header = e.headers.get("Server", "")
    error = f"http_error: {e}"
except URLError as e:
    error = f"url_error: {e}"
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
f"""# FASE 87 — ODOO Smoke Web Probe

## Probe
- target: {target}
- http_ok: {http_ok}
- login_page_ok: {login_page_ok}
- status_code: {status_code}
- server_header: {server_header}

## Governança
- deploy_executed: false
- production_changed: false
"""
)

print(f"[OK] smoke web probe gerado em {out_json}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
