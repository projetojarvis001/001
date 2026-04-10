#!/usr/bin/env python3
import json
import ssl
import urllib.request
import xmlrpc.client
from datetime import datetime, timezone
from pathlib import Path
import os

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

base = Path("logs/executive")
docs = Path("docs/generated")
base.mkdir(parents=True, exist_ok=True)
docs.mkdir(parents=True, exist_ok=True)

ts = datetime.now().strftime("%Y%m%d-%H%M%S")
out_json = base / f"phase83_odoo_post_apply_probe_{ts}.json"
out_md = docs / f"phase83_odoo_post_apply_probe_{ts}.md"

url = os.getenv("ODOO_URL", "").rstrip("/")
db = os.getenv("ODOO_DB", "")
user = os.getenv("ODOO_APP_USER", "")
password = os.getenv("ODOO_APP_PASS", "")

http_ok = False
xmlrpc_common_ok = False
auth_ok = False
uid = 0
version_info = {}
error_msg = ""

try:
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=20, context=ssl._create_unverified_context()) as resp:
        http_ok = 200 <= resp.status < 500
except Exception as e:
    error_msg = f"http_error: {e}"

try:
    common = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/common", allow_none=True)
    version_info = common.version()
    xmlrpc_common_ok = True
    uid = common.authenticate(db, user, password, {})
    auth_ok = bool(uid)
except Exception as e:
    if error_msg:
        error_msg += " | "
    error_msg += f"xmlrpc_error: {e}"

payload = {
    "created_at": utc_now(),
    "post_apply_probe": {
        "url": url,
        "db": db,
        "http_ok": http_ok,
        "xmlrpc_common_ok": xmlrpc_common_ok,
        "auth_ok": auth_ok,
        "uid": uid,
        "server_version": version_info.get("server_version", ""),
        "error": error_msg
    },
    "governance": {
        "deploy_executed": True,
        "production_changed": True
    }
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
out_md.write_text(
f"""# FASE 83 — ODOO Post Apply Probe

## Probe
- url: {url}
- db: {db}
- http_ok: {http_ok}
- xmlrpc_common_ok: {xmlrpc_common_ok}
- auth_ok: {auth_ok}
- uid: {uid}
- server_version: {version_info.get('server_version', '')}

## Governança
- deploy_executed: true
- production_changed: true
"""
)

print(f"[OK] post apply probe gerado em {out_json}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
