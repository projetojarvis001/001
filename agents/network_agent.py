#!/usr/bin/env python3
"""
Agente de Rede JARVIS — diagnóstico autônomo via FRIDAY
Ativado por: !rede ou !network no Telegram
"""
import sys, os, warnings, requests, json, subprocess
warnings.filterwarnings('ignore')
sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')

from dotenv import load_dotenv
load_dotenv('/Users/jarvis001/jarvis/.env')

FRIDAY_URL = 'http://192.168.8.36:8877'
VISION_URL = 'http://192.168.8.124:5006'
GROQ_KEY = os.getenv('GROQ_API_KEY')

from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage

llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.1)

def run_on_friday(cmd: str, timeout: int = 30) -> dict:
    try:
        r = requests.post(FRIDAY_URL,
            json={'id': 'net_diag', 'command': cmd},
            timeout=timeout)
        if r.status_code == 200:
            return r.json()
        return {'ok': False, 'stdout': '', 'stderr': f'HTTP {r.status_code}'}
    except Exception as e:
        return {'ok': False, 'stdout': '', 'stderr': str(e)}

def run_local(cmd: str) -> str:
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
        return r.stdout.strip()
    except:
        return ''

def diagnose(query: str) -> str:
    print(f"[NetAgent] Diagnóstico: {query[:80]}")
    
    # Coleta dados de rede locais (JARVIS)
    local_data = {}
    local_data['public_ip'] = run_local("curl -fsS https://api.ipify.org 2>/dev/null")
    local_data['latency_cf'] = run_local("ping -c 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}'")
    local_data['latency_google'] = run_local("ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}'")
    local_data['connections'] = run_local("netstat -an 2>/dev/null | grep ESTABLISHED | wc -l | tr -d ' '")
    local_data['tailscale'] = run_local("tailscale status 2>/dev/null | head -5")

    # Coleta dados de rede no FRIDAY
    friday_net = {}
    r = run_on_friday("hostname && ip addr show | grep 'inet ' | grep -v '127.0' | head -3")
    friday_net['interfaces'] = r.get('stdout', '')[:200]
    
    r = run_on_friday("ping -c 3 192.168.8.121 2>/dev/null | tail -1")
    friday_net['ping_jarvis'] = r.get('stdout', '')
    
    r = run_on_friday("ping -c 3 1.1.1.1 2>/dev/null | tail -1")
    friday_net['ping_internet'] = r.get('stdout', '')
    
    r = run_on_friday("ss -tlnp | head -10")
    friday_net['ports'] = r.get('stdout', '')[:300]
    
    r = run_on_friday("free -h | head -2 && df -h / | tail -1")
    friday_net['resources'] = r.get('stdout', '')[:200]

    # Verifica conectividade dos 4 nós via Tailscale
    nodes = {
        'JARVIS': 'http://localhost:3000/health',
        'VISION': 'http://192.168.8.124:5006/health',
        'FRIDAY': 'http://192.168.8.36:8877/health',
    }
    node_status = {}
    for name, url in nodes.items():
        try:
            rr = requests.get(url, timeout=5)
            node_status[name] = f"✅ {rr.status_code}"
        except Exception as e:
            node_status[name] = f"❌ offline"

    # Monta relatório para o LLM analisar
    report = f"""
DADOS DE REDE COLETADOS:

JARVIS (192.168.8.121):
- IP público: {local_data['public_ip']}
- Latência Cloudflare: {local_data['latency_cf']}ms
- Latência Google: {local_data['latency_google']}ms
- Conexões ativas: {local_data['connections']}
- Tailscale: {local_data['tailscale'][:100]}

FRIDAY (192.168.8.36):
- Interfaces: {friday_net['interfaces']}
- Ping JARVIS: {friday_net['ping_jarvis']}
- Ping Internet: {friday_net['ping_internet']}
- Portas ativas: {friday_net['ports'][:150]}
- Recursos: {friday_net['resources']}

STATUS DOS NÓS:
{json.dumps(node_status, indent=2)}

PERGUNTA DO USUÁRIO: {query}
"""

    # LLM analisa e responde
    response = llm.invoke([
        SystemMessage(content="""Você é o agente de rede do J.A.R.V.I.S. 
Analise os dados de rede coletados e responda a pergunta do usuário.
Seja específico: cite valores reais (latência, IPs, status).
Se detectar problema, explique qual é e como resolver.
Se tudo estiver OK, confirme com os dados que embasam essa conclusão.
Responda em português do Brasil, de forma direta e técnica."""),
        HumanMessage(content=report)
    ])
    
    return response.content

if __name__ == '__main__':
    query = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else "qual o status da rede?"
    print(f"\n{'='*60}")
    print(f"DIAGNÓSTICO: {query}")
    print('='*60)
    result = diagnose(query)
    print(f"\nRESPOSTA:\n{result}")
