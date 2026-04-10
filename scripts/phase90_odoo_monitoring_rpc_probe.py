#!/usr/bin/env python3
import json
import os
import xmlrpc.client
from datetime import datetime, timezone
from pathlib import Path

BASE = Path("logs/executive")
DOCS = Path("docs/generated")
BASE.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
out_json = BASE / f"phase90_odoo_monitoring_rpc_probe_{ts}.json"
out_md = DOCS / f"phase90_odoo_monitoring_rpc_probe_{ts}.md"

url = os.environ["ODOO_URL"].rstrip("/")
db = os.environ["ODOO_DB"]
user = os.environ["ODOO_APP_USER"]
password = os.environ["ODOO_APP_PASS"]

xmlrpc_common_ok = False
auth_ok = False
uid = 0
server_version = ""
protocol_version = 0
error = ""

try:
    common = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/common", allow_none=True)
    version_info = common.version()
    xmlrpc_common_ok = True
    server_version = version_info.get("server_version", "")
    protocol_version = version_info.get("protocol_version", 0)
    uid = common.authenticate(db, user, password, {})
    auth_ok = bool(uid)
except Exception as e:
    error = str(e)

payload = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "rpc_probe": {
        "url": url,
        "db": db,
        "xmlrpc_common_ok": xmlrpc_common_ok,
        "auth_ok": auth_ok,
        "uid": uid,
        "server_version": server_version,
        "protocol_version": protocol_version,
        "error": error
    },
    "governance": {
        "deploy_executed": False,
        "production_changed": False
    }
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
out_md.write_text(
f"""# FASE 90 — ODOO Monitoring RPC Probe

## Probe
- url: {url}
- db: {db}
- xmlrpc_common_ok: {xmlrpc_common_ok}
- auth_ok: {auth_ok}
- uid: {uid}
- server_version: {server_version}
- protocol_version: {protocol_version}
- error: {error}

## Governança
- deploy_executed: false
- production_changed: false
"""
)

print(f"[OK] monitoring rpc probe gerado em {out_json}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
