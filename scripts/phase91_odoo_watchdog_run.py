#!/usr/bin/env python3
import json
import os
import urllib.request
import urllib.error
import xmlrpc.client
from datetime import datetime, timezone
from pathlib import Path

BASE = Path("logs/executive")
DOCS = Path("docs/generated")
BASE.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_json = BASE / f"phase91_odoo_watchdog_run_{ts}.json"
    out_md = DOCS / f"phase91_odoo_watchdog_run_{ts}.md"

    url = os.environ["ODOO_URL"].rstrip("/")
    db = os.environ["ODOO_DB"]
    user = os.environ["ODOO_APP_USER"]
    password = os.environ["ODOO_APP_PASS"]

    web_ok = False
    login_ok = False
    status_code = 0
    server_header = ""
    web_error = ""

    try:
        req = urllib.request.Request(
            f"{url}/web/login",
            headers={"User-Agent": "jarvis-phase91-watchdog"}
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            status_code = getattr(resp, "status", 200)
            body = resp.read().decode("utf-8", errors="ignore")
            server_header = resp.headers.get("Server", "")
            web_ok = 200 <= status_code < 400
            login_ok = ("login" in body.lower()) or ("/web/login" in body.lower())
    except Exception as e:
        web_error = f"{type(e).__name__}: {e}"

    rpc_ok = False
    auth_ok = False
    uid = 0
    server_version = ""
    protocol_version = 0
    rpc_error = ""

    try:
        common = xmlrpc.client.ServerProxy(f"{url}/xmlrpc/2/common", allow_none=True)
        version_info = common.version()
        rpc_ok = True
        server_version = version_info.get("server_version", "")
        protocol_version = version_info.get("protocol_version", 0)
        uid = common.authenticate(db, user, password, {})
        auth_ok = bool(uid)
    except Exception as e:
        rpc_error = f"{type(e).__name__}: {e}"

    overall_ok = web_ok and login_ok and rpc_ok and auth_ok

    payload = {
        "created_at": utc_now(),
        "watchdog_run": {
            "url": url,
            "db": db,
            "web_ok": web_ok,
            "login_ok": login_ok,
            "status_code": status_code,
            "server_header": server_header,
            "rpc_ok": rpc_ok,
            "auth_ok": auth_ok,
            "uid": uid,
            "server_version": server_version,
            "protocol_version": protocol_version,
            "overall_ok": overall_ok,
            "web_error": web_error,
            "rpc_error": rpc_error
        },
        "governance": {
            "deploy_executed": False,
            "production_changed": False
        }
    }

    out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    out_md.write_text(
f"""# FASE 91 — ODOO Watchdog Run

## Resultado
- url: {url}
- db: {db}
- web_ok: {web_ok}
- login_ok: {login_ok}
- status_code: {status_code}
- server_header: {server_header}
- rpc_ok: {rpc_ok}
- auth_ok: {auth_ok}
- uid: {uid}
- server_version: {server_version}
- overall_ok: {overall_ok}

## Governança
- deploy_executed: false
- production_changed: false
"""
    )

    print(f"[OK] watchdog run gerado em {out_json}")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
