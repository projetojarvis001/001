#!/usr/bin/env python3
"""Servidor HTTP para o agente LangGraph — porta 7782"""
import sys, os, warnings, json
warnings.filterwarnings('ignore')
sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')
from http.server import HTTPServer, BaseHTTPRequestHandler
from autonomous_agent import run_auto as run

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length))
        task = body.get('task', '')
        print(f"[AutoServer] Task: {task[:80]}")
        try:
            result = run(task)
            resp = json.dumps({'ok': True, 'response': result}).encode()
            self.send_response(200)
        except Exception as e:
            resp = json.dumps({'ok': False, 'error': str(e)}).encode()
            self.send_response(500)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(resp)
    def do_POST_approve(self, body):
        try:
            from approval_system import process_approval_response
            ok = process_approval_response(body.get("response",""))
            return json.dumps({"ok": ok}).encode()
        except Exception as e:
            return json.dumps({"ok": False, "error": str(e)}).encode()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))
        if self.path == "/approve":
            resp = self.do_POST_approve(body)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(resp)
            return
        task = body.get("task", "status dos servicos")
        try:
            result = run_auto(task)
            resp = json.dumps({"ok": True, "response": result}).encode()
            self.send_response(200)
        except Exception as e:
            resp = json.dumps({"ok": False, "error": str(e)}).encode()
            self.send_response(500)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(resp)

    def do_GET(self):
        resp = json.dumps({'ok': True, 'service': 'auto-agent'}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(resp)

if __name__ == '__main__':
    print('[AutoServer] Iniciando em :7782')
    HTTPServer(('0.0.0.0', 7782), Handler).serve_forever()
