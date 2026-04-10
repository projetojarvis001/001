#!/usr/bin/env python3
import json
import os
import xmlrpc.client
from datetime import datetime, timezone
from pathlib import Path
import subprocess

BASE = Path("logs/executive")
DOCS = Path("docs/generated")
BASE.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
out_json = BASE / f"phase89_odoo_drill_auth_probe_{ts}.json"
out_md = DOCS / f"phase89_odoo_drill_auth_probe_{ts}.md"

seed_file = sorted(Path("logs/executive").glob("phase89_odoo_drill_seed_*.json"))[-1]
seed = json.loads(seed_file.read_text())

url = os.environ["ODOO_URL"].rstrip("/")
drill_db = seed["seed"]["drill_db"]
user = os.environ["ODOO_APP_USER"]
password = os.environ["ODOO_APP_PASS"]

xmlrpc_common_ok = False
auth_ok = False
uid = 0
server_version = ""
error = ""

try:
    common = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/common", allow_none=True)
    version_info = common.version()
    xmlrpc_common_ok = True
    server_version = version_info.get("server_version", "")
    uid = common.authenticate(drill_db, user, password, {})
    auth_ok = bool(uid)
except Exception as e:
    error = str(e)

payload = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "drill_auth_probe": {
        "url": url,
        "drill_db": drill_db,
        "xmlrpc_common_ok": xmlrpc_common_ok,
        "auth_ok": auth_ok,
        "uid": uid,
        "server_version": server_version,
        "error": error
    },
    "governance": {
        "deploy_executed": False,
        "production_changed": False
    }
}

out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
out_md.write_text(
f"""# FASE 89 — ODOO Drill Auth Probe

## Probe
- url: {url}
- drill_db: {drill_db}
- xmlrpc_common_ok: {xmlrpc_common_ok}
- auth_ok: {auth_ok}
- uid: {uid}
- server_version: {server_version}
- error: {error}

## Governança
- deploy_executed: false
- production_changed: false
"""
)

print(f"[OK] drill auth probe gerado em {out_json}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
