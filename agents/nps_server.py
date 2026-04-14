#!/usr/bin/env python3
import sys, os, warnings, json
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from http.server import HTTPServer, BaseHTTPRequestHandler
from nps_agent import run

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))
        try:
            result = run(body.get("task","relatorio"))
            resp = json.dumps({"ok": True, "response": result}).encode()
            self.send_response(200)
        except Exception as e:
            resp = json.dumps({"ok": False, "error": str(e)}).encode()
            self.send_response(500)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(resp)
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"ok": True, "service": "nps-agent"}).encode())

if __name__ == "__main__":
    print("[NPSServer] :7791")
    HTTPServer(("0.0.0.0", 7791), Handler).serve_forever()
