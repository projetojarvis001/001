#!/usr/bin/env python3
"""
J.A.R.V.I.S. — Agente Executivo LangGraph
Raciocina em cadeia: Entende → Busca contexto RAG → Age → Reporta
"""
import sys, os, warnings, requests, json
warnings.filterwarnings('ignore')
sys.path.insert(0, '/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')

from typing import TypedDict, Annotated
from langgraph.graph import StateGraph, END
from langchain_groq import ChatGroq
try:
    from cost_router import ask as router_ask
    COST_ROUTER_AVAILABLE = True
except:
    COST_ROUTER_AVAILABLE = False
from langchain_core.messages import HumanMessage, SystemMessage
from dotenv import load_dotenv
from jarvis_context import WAGNER_CONTEXT

load_dotenv('/Users/jarvis001/jarvis/.env')

GROQ_KEY = os.getenv('GROQ_API_KEY')
VISION_URL = 'http://192.168.8.124:5006'
FRIDAY_URL = 'http://192.168.8.36:8877'
BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')

llm = ChatGroq(api_key=GROQ_KEY, model="llama-3.3-70b-versatile", temperature=0.2)

# ── Estado do agente ──────────────────────────────────────────
class AgentState(TypedDict):
    task: str           # tarefa recebida
    context: str        # contexto RAG do VISION
    plan: str           # plano de execução gerado
    result: str         # resultado final
    needs_execution: bool
    execution_cmd: str

# ── Nó 1: Entender a tarefa ──────────────────────────────────
def understand(state: AgentState) -> AgentState:
    task = state['task']
    print(f"[JARVIS] Entendendo: {task[:80]}...")
    
    response = llm.invoke([
        SystemMessage(content="""Você é J.A.R.V.I.S., assistente executivo do Grupo Wagner.
Analise a tarefa e classifique:
- needs_execution: true se requer rodar comando no servidor, false se é só análise/resposta
- execution_cmd: comando bash a executar (vazio se não precisar)
Responda APENAS em JSON: {"needs_execution": bool, "execution_cmd": "cmd ou vazio", "summary": "resumo da tarefa"}"""),
        HumanMessage(content=f"Tarefa: {task}")
    ])
    
    try:
        clean = response.content.strip()
        if '```' in clean:
            clean = clean.split('```')[1].replace('json','').strip()
        data = json.loads(clean)
        state['needs_execution'] = data.get('needs_execution', False)
        state['execution_cmd'] = data.get('execution_cmd', '')
        print(f"[JARVIS] Classificado: execução={'sim' if state['needs_execution'] else 'não'}")
    except:
        state['needs_execution'] = False
        state['execution_cmd'] = ''
    
    return state

# ── Nó 2: Buscar contexto RAG no VISION ──────────────────────
def search_context(state: AgentState) -> AgentState:
    task = state['task']
    print(f"[JARVIS] Buscando contexto RAG + memorias no VISION...")
    memories = get_memories(task)
    
    try:
        r = requests.post(f'{VISION_URL}/search-and-generate',
            json={'query': task, 'prompt': f'Forneça contexto relevante sobre: {task}',
                  'model': 'qwen2.5:7b', 'limit': 3},
            timeout=30)
        if r.status_code == 200:
            data = r.json()
            state['context'] = data.get('response', '')[:1000]
            print(f"[JARVIS] Contexto obtido: {len(state['context'])} chars")
        else:
            state['context'] = 'Contexto não disponível'
    except Exception as e:
        state['context'] = f'VISION offline: {e}'
        print(f"[JARVIS] VISION offline, continuando sem RAG")
    
    return state

# ── Nó 3: Planejar e responder ────────────────────────────────
def plan_and_respond(state: AgentState) -> AgentState:
    task = state['task']
    context = state['context']
    print(f"[JARVIS] Gerando resposta com Groq...")
    
    response = llm.invoke([
        SystemMessage(content=f"""Você é J.A.R.V.I.S., assistente executivo do Grupo Wagner BRASILEIRO.
Wagner Silva é empresário brasileiro, fundador do Grupo Wagner holding com 9 empresas (WPS Digital, Grape Networks, hubOS, Integracondo e outras).
WPS Digital: 25 anos, TI e segurança eletrônica para condomínios, CFTV, controle de acesso, redes, automação.
NÃO tem relação com grupo mercenário russo.

REGRA CRÍTICA: O CONTEXTO RAG ABAIXO contém informações reais do Grupo Wagner. 
USE OBRIGATORIAMENTE essas informações na resposta. Cite dados específicos. Não invente.

CONTEXTO RAG (use estas informações diretamente):
{context[:1000]}

Responda em português do Brasil, seja específico e direto. Use os dados do contexto acima."""),
        HumanMessage(content=task)
    ])
    
    state['result'] = response.content
    print(f"[JARVIS] Resposta gerada: {len(state['result'])} chars")
    save_memory(task, response.content)
    return state

# ── Nó 4: Executar no FRIDAY (se necessário) ─────────────────
def execute_on_friday(state: AgentState) -> AgentState:
    cmd = state.get('execution_cmd', '')
    if not cmd:
        return state
    
    print(f"[JARVIS] Executando no FRIDAY: {cmd[:60]}...")
    try:
        r = requests.post(FRIDAY_URL,
            json={'id': 'langgraph_001', 'command': cmd},
            timeout=60)
        if r.status_code == 200:
            data = r.json()
            output = data.get('stdout', '')[:500]
            state['result'] = f"{state['result']}\n\n**Execução FRIDAY:**\n```\n{output}\n```"
            print(f"[JARVIS] Execução concluída: returncode={data.get('returncode')}")
    except Exception as e:
        print(f"[JARVIS] Erro na execução: {e}")
    
    return state

# ── Roteador: precisa executar? ───────────────────────────────
def should_execute(state: AgentState) -> str:
    return "execute" if state.get('needs_execution') and state.get('execution_cmd') else "respond"

# ── Construir o grafo ─────────────────────────────────────────
def build_graph():
    graph = StateGraph(AgentState)
    
    graph.add_node("understand", understand)
    graph.add_node("search_context", search_context)
    graph.add_node("plan_and_respond", plan_and_respond)
    graph.add_node("execute_on_friday", execute_on_friday)
    
    graph.set_entry_point("understand")
    graph.add_edge("understand", "search_context")
    graph.add_edge("search_context", "plan_and_respond")
    graph.add_conditional_edges("plan_and_respond", should_execute, {
        "execute": "execute_on_friday",
        "respond": END
    })
    graph.add_edge("execute_on_friday", END)
    
    return graph.compile()

# ── Interface pública ─────────────────────────────────────────
def run(task: str) -> str:
    app = build_graph()
    result = app.invoke({
        'task': task,
        'context': '',
        'plan': '',
        'result': '',
        'needs_execution': False,
        'execution_cmd': ''
    })
    return result['result']

if __name__ == '__main__':
    task = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else "qual o status do sistema JARVIS?"
    print(f"\n{'='*60}")
    print(f"TAREFA: {task}")
    print('='*60)
    result = run(task)
    print(f"\nRESPOSTA:\n{result}")
