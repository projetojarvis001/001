#!/usr/bin/env python3
"""
JARVIS Metrics Exporter — Prometheus
Expoe metricas reais dos agentes para o Grafana
Porta: 9091
"""
import sys, os, time, subprocess, requests
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
from http.server import HTTPServer, BaseHTTPRequestHandler
import psutil

AGENTS = {
    "jarvis": 7777, "network": 7778, "outlook": 7779,
    "odoo": 7780, "hunter": 7781, "auto": 7782,
    "intel": 7783, "prospect": 7784, "financial": 7785,
    "contract": 7786, "email": 7787, "agenda": 7788,
    "cobranca": 7789, "relatorio": 7790, "nps": 7791
}

def check_agent(port):
    try:
        r = requests.get(f"http://localhost:{port}", timeout=3)
        return 1 if r.status_code == 200 else 0
    except: return 0

def get_metrics():
    lines = []
    lines.append("# HELP jarvis_agent_up Agent health status")
    lines.append("# TYPE jarvis_agent_up gauge")
    for name, port in AGENTS.items():
        status = check_agent(port)
        lines.append(f'jarvis_agent_up{{agent="{name}",port="{port}"}} {status}')
    
    lines.append("# HELP jarvis_agents_total Total agents online")
    lines.append("# TYPE jarvis_agents_total gauge")
    total = sum(check_agent(p) for p in AGENTS.values())
    lines.append(f"jarvis_agents_total {total}")
    
    lines.append("# HELP system_cpu_percent CPU usage")
    lines.append("# TYPE system_cpu_percent gauge")
    lines.append(f"system_cpu_percent {psutil.cpu_percent(interval=1)}")
    
    lines.append("# HELP system_memory_percent Memory usage")
    lines.append("# TYPE system_memory_percent gauge")
    mem = psutil.virtual_memory()
    lines.append(f"system_memory_percent {mem.percent}")
    lines.append(f"system_memory_used_gb {mem.used/1024/1024/1024:.2f}")
    lines.append(f"system_memory_total_gb {mem.total/1024/1024/1024:.2f}")
    
    lines.append("# HELP system_disk_percent Disk usage")
    lines.append("# TYPE system_disk_percent gauge")
    disk = psutil.disk_usage("/")
    lines.append(f"system_disk_percent {disk.percent}")
    
    try:
        r = requests.get("http://192.168.8.124:5006/stats", timeout=5)
        kb_total = r.json().get("vectors_total", 0)
        lines.append("# HELP jarvis_kb_vectors Knowledge base vectors")
        lines.append("# TYPE jarvis_kb_vectors gauge")
        lines.append(f"jarvis_kb_vectors {kb_total}")
    except: pass
    
    try:
        result = subprocess.run(["docker","ps","--format","{{.Names}}"],
            capture_output=True, text=True, timeout=5)
        n = len([c for c in result.stdout.strip().split("\n") if c])
        lines.append("# HELP docker_containers_running Running containers")
        lines.append("# TYPE docker_containers_running gauge")
        lines.append(f"docker_containers_running {n}")
    except: pass
    
    return "\n".join(lines)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass
    def do_GET(self):
        if self.path == "/metrics":
            metrics = get_metrics()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(metrics.encode())
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true,"service":"metrics-exporter","port":9091}')

if __name__ == "__main__":
    print("[MetricsExporter] :9091 /metrics")
    HTTPServer(("0.0.0.0", 9091), Handler).serve_forever()
