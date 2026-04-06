from http.server import HTTPServer, BaseHTTPRequestHandler
import json, sys, subprocess
sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')

class PropostaHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/gerar-proposta':
            length = int(self.headers.get('Content-Length', 0))
            data = json.loads(self.rfile.read(length))
            
            result = subprocess.run([
                '/usr/bin/python3',
                '/Users/jarvis001/jarvis/scripts/gerar_proposta_docx.py'
            ], capture_output=True, text=True, env={
                'CLIENTE': data.get('cliente',''),
                'SINDICO': data.get('sindico',''),
                'UNIDADES': str(data.get('unidades',100)),
            })
            
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'ok': True,
                'file': f"/tmp/proposta_wps_{data.get('cliente','').replace(' ','_')}.docx",
                'output': result.stdout.strip()
            }).encode())
    
    def log_message(self, format, *args): pass

print("Proposta endpoint :7070")
HTTPServer(('0.0.0.0', 7070), PropostaHandler).serve_forever()
