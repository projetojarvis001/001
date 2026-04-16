#!/usr/bin/env python3
"""
KNOWLEDGE DAILY :5012
Auto-alimentacao diaria de conhecimento
Todo dia escolhe 1 tema, pesquisa, aprofunda, distribui para todos os agentes
e reporta no Telegram o que aprendeu
"""
import sys, os, json, datetime, threading, time, hashlib, sqlite3
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
import requests
from fastapi import FastAPI
import uvicorn
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

app = FastAPI(title="Knowledge Daily v1")
BOT = os.getenv("TELEGRAM_BOT_TOKEN","")
CHAT = os.getenv("TELEGRAM_CHAT_ID","")
VISION = "http://192.168.8.124:5006"
SHADOW = "http://192.168.8.124:5009"
MEMORY = "http://localhost:5010"
DB = "/Users/jarvis001/jarvis/data/knowledge_daily.db"

# Temas organizados por categoria — rotacao inteligente sem repeticao proxima
TEMAS = {
    "vendas_wps": [
        "tecnicas avancadas SPIN selling para portaria virtual condominial",
        "psicologia da decisao do sindico profissional brasileiro",
        "como estruturar proposta de valor portaria virtual para diferentes perfis",
        "negociacao avancada com administradoras de condominio",
        "storytelling em vendas B2B para seguranca eletronica",
        "follow up cientifico baseado em dados taxa de conversao",
        "como criar urgencia genuina na venda de portaria virtual",
        "tecnicas de ancoragem de preco em vendas de servico recorrente",
    ],
    "mercado_condominial": [
        "tendencias mercado condominial Brasil 2026 2027",
        "impacto da Lei Geral dos Condomínios na seguranca eletronica",
        "perfil demografico sindico profissional regiao sudeste",
        "crescimento vertical urbano Campinas e Ribeirao Preto dados recentes",
        "administradoras de condominio maiores do Brasil ranking",
        "movimento sindico profissional associacoes AABIC SECOVI",
        "smart buildings tendencias tecnologia condominial",
        "energia solar em condomínios impacto no orcamento e seguranca",
    ],
    "tecnologia_seguranca": [
        "evolucao cameras CFTV inteligencia artificial 2026",
        "controle acesso biometrico facial vs QR code comparativo",
        "LPR reconhecimento de placas tecnologia atual",
        "LGPD cameras seguranca condomínio obrigacoes legais",
        "IoT sensores seguranca perimetral condominial",
        "deep learning deteccao anomalias vigilancia",
        "cloud vs local armazenamento gravacoes seguranca",
        "5G impacto na portaria virtual latencia e qualidade",
    ],
    "gestao_empresarial": [
        "OKRs para empresa de seguranca eletronica B2B",
        "modelo SaaS aplicado a servicos de portaria virtual recorrente",
        "Customer Success em empresas de seguranca condominial",
        "NPS como ferramenta de crescimento organico WPS",
        "churn prediction modelos preditivos para contratos de seguranca",
        "LTV CAC otimizacao empresa servicos recorrentes",
        "expansion revenue upsell cross-sell em seguranca eletronica",
        "pricing strategy para servicos condominiais recorrentes",
    ],
    "inteligencia_artificial": [
        "RAG Retrieval Augmented Generation melhores praticas 2026",
        "fine-tuning LLMs com dados proprietarios empresa",
        "agentes autonomos aplicacoes empresariais reais",
        "prompt engineering avancado para respostas comerciais",
        "vector databases pgvector vs alternatives comparativo",
        "LLMs locais vs API custo beneficio empresa",
        "AI em vendas B2B casos de uso reais resultados",
        "machine learning previsao churn clientes recorrentes",
    ],
    "financeiro_negocios": [
        "valuation empresas SaaS multiplos receita recorrente",
        "modelagem financeira MRR ARR projecoes",
        "M&A empresas seguranca eletronica Brasil consolidacao",
        "captacao investimento venture capital seguranca",
        "estrutura societaria holding familiar otimizacao fiscal",
        "fusoes aquisicoes pequenas empresas tecnologia Brasil",
        "precificacao servicos B2B margens saudaveis seguranca",
        "benchmark financeiro empresas seguranca condominial",
    ],
    "lideranca_estrategia": [
        "escala empresas de servico de R$1M para R$10M ARR",
        "contratacao e retencao talentos tecnologia interior SP",
        "cultura organizacional empresas tech Brasil",
        "delegacao eficaz usando IA e automacao",
        "tomada de decisao baseada em dados pequenas empresas",
        "parcerias estrategicas canais indiretos seguranca",
        "expansao geografica playbook replicavel",
        "construcao de marca B2B seguranca eletronica",
    ],
}

def init_db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS historico (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT,
            categoria TEXT,
            tema TEXT,
            conteudo TEXT,
            vetores_adicionados INTEGER DEFAULT 0,
            reportado INTEGER DEFAULT 0
        )
    """)
    conn.commit()
    conn.close()

init_db()

def telegram(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg}, timeout=5)
    except: pass

def get_proxima_categoria():
    """Rotaciona categorias para nao repetir a mesma seguida"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT categoria FROM historico ORDER BY id DESC LIMIT 7")
    recentes = [r[0] for r in cur.fetchall()]
    conn.close()
    todas = list(TEMAS.keys())
    # Prioriza categorias que nao apareceram recentemente
    disponiveis = [c for c in todas if c not in recentes[:3]]
    if not disponiveis:
        disponiveis = todas
    import random
    return random.choice(disponiveis)

def get_proximo_tema(categoria):
    """Escolhe tema da categoria que ainda nao foi usado"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT tema FROM historico WHERE categoria=?", (categoria,))
    usados = [r[0] for r in cur.fetchall()]
    conn.close()
    temas = TEMAS.get(categoria, [])
    disponiveis = [t for t in temas if t not in usados]
    if not disponiveis:
        disponiveis = temas  # reinicia ciclo
    import random
    return random.choice(disponiveis)

def pesquisa_e_aprofunda(tema: str) -> dict:
    """Usa o JARVIS para pesquisar e aprofundar o tema em multiplas perspectivas"""
    sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
    from cost_router import ask
    from jarvis_context import SYSTEM_PROMPT_JARVIS

    resultados = {}

    # Busca contexto atual no KB
    try:
        r = requests.post(f"{VISION}/search",
            json={"query": tema, "limit": 4}, timeout=15)
        ctx_existente = "\n".join([
            f"{x.get('title','')}: {x.get('content','')[:200]}"
            for x in r.json().get('results',[])[:3]
        ])
    except:
        ctx_existente = ""

    # Gera 5 perspectivas do tema
    perspectivas = [
        f"explique de forma completa e pratica: {tema}. Foque em aplicacao real para a WPS Digital.",
        f"quais os 5 pontos mais importantes sobre: {tema}. Com exemplos numericos e casos reais.",
        f"como {tema} se aplica especificamente ao mercado condominial brasileiro e para a WPS Digital?",
        f"quais as melhores praticas e armadilhas a evitar em: {tema}?",
        f"como implementar na pratica: {tema}? Passo a passo para uma empresa como a WPS Digital.",
    ]

    conteudo_completo = []
    for i, perspectiva in enumerate(perspectivas):
        try:
            prompt = f"Contexto WPS:\n{ctx_existente}\n\nPERGUNTA: {perspectiva}\nResposta completa e detalhada, max 300 palavras."
            resp = ask(prompt, system=SYSTEM_PROMPT_JARVIS)
            conteudo = resp.get('content', '')
            if conteudo:
                conteudo_completo.append({
                    "perspectiva": i+1,
                    "pergunta": perspectiva,
                    "conteudo": conteudo,
                    "provider": resp.get('provider','groq')
                })
            time.sleep(0.5)
        except Exception as e:
            pass

    resultados['perspectivas'] = conteudo_completo
    resultados['tema'] = tema
    return resultados

def distribui_conhecimento(tema: str, perspectivas: list) -> int:
    """Ingere o conhecimento no KB e distribui para Shadow e Memoria"""
    docs_adicionados = 0

    for p in perspectivas:
        conteudo = p.get('conteudo','')
        if not conteudo:
            continue

        # 1. Ingere no KB (Semantic API)
        doc_id = hashlib.md5(f"{tema}_{p['perspectiva']}".encode()).hexdigest()[:12]
        try:
            requests.post(f"{VISION}/ingest", json={"items": [{
                "id": doc_id,
                "title": f"Daily Knowledge: {tema[:60]} (p{p['perspectiva']})",
                "content": conteudo,
                "category": "knowledge_daily"
            }]}, timeout=30)
            docs_adicionados += 1
        except: pass

        # 2. Loga no Hermes Shadow para aprendizado
        try:
            requests.post(f"{SHADOW}/log", json={
                "pergunta": p['pergunta'][:100],
                "resposta": conteudo[:300],
                "provider": p.get('provider','groq'),
                "agente": "knowledge_daily"
            }, timeout=3)
        except: pass

        time.sleep(0.2)

    # 3. Registra na Memoria como conhecimento do dia
    try:
        requests.post(f"{MEMORY}/lembrar", json={
            "tipo": "knowledge_daily",
            "conteudo": f"Hoje aprendi sobre: {tema}. {len(perspectivas)} perspectivas adicionadas ao KB.",
            "relevancia": 8
        }, timeout=3)
    except: pass

    return docs_adicionados

def gera_resumo_telegram(tema: str, perspectivas: list, vetores: int) -> str:
    """Gera resumo executivo para enviar no Telegram"""
    sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
    from cost_router import ask
    from jarvis_context import SYSTEM_PROMPT_JARVIS

    conteudo_dia = "\n\n".join([
        f"Perspectiva {p['perspectiva']}: {p['conteudo'][:200]}"
        for p in perspectivas[:3]
    ])

    try:
        resp = ask(
            f"Faca um resumo executivo em 5 bullet points do que foi aprendido hoje sobre: {tema}\n\nConteudo:\n{conteudo_dia}\n\nSeja direto, use dados quando houver, max 200 palavras total.",
            system=SYSTEM_PROMPT_JARVIS
        )
        resumo = resp.get('content','')
    except:
        resumo = f"Tema estudado com {len(perspectivas)} perspectivas."

    data_hoje = datetime.date.today().strftime("%d/%m/%Y")
    msg = f"JARVIS Knowledge Daily — {data_hoje}\n\n"
    msg += f"Tema: {tema}\n\n"
    msg += f"{resumo}\n\n"
    msg += f"Distribuido para: KB ({vetores} docs) + Hermes Shadow + Memoria\n"
    msg += f"Use !jarvis para perguntar sobre este tema."
    return msg

def ciclo_diario():
    """Roda uma vez por dia as 6h"""
    while True:
        try:
            agora = datetime.datetime.now()
            if agora.hour == 6 and agora.minute < 10:
                executar_knowledge_daily()
        except Exception as e:
            pass
        time.sleep(600)  # verifica a cada 10 minutos

def executar_knowledge_daily():
    """Executa o ciclo completo de conhecimento do dia"""
    print(f"[Knowledge Daily] Iniciando ciclo {datetime.date.today()}")

    # Verifica se ja rodou hoje
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT id FROM historico WHERE data=?", (str(datetime.date.today()),))
    ja_rodou = cur.fetchone()
    conn.close()

    if ja_rodou:
        print("[Knowledge Daily] Ja rodou hoje")
        return {"ok": False, "msg": "ja rodou hoje"}

    # Escolhe tema
    categoria = get_proxima_categoria()
    tema = get_proximo_tema(categoria)
    print(f"[Knowledge Daily] Categoria: {categoria} | Tema: {tema}")
    telegram(f"JARVIS Knowledge Daily — iniciando\n\nCategoria: {categoria}\nTema: {tema}\n\nPesquisando e aprofundando...")

    # Pesquisa e aprofunda
    resultado = pesquisa_e_aprofunda(tema)
    perspectivas = resultado.get('perspectivas', [])
    print(f"[Knowledge Daily] {len(perspectivas)} perspectivas geradas")

    # Distribui conhecimento
    vetores = distribui_conhecimento(tema, perspectivas)
    print(f"[Knowledge Daily] {vetores} vetores adicionados ao KB")

    # Salva no historico
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO historico (data, categoria, tema, conteudo, vetores_adicionados, reportado)
        VALUES (?, ?, ?, ?, ?, 1)
    """, (str(datetime.date.today()), categoria, tema,
          json.dumps([p['conteudo'][:200] for p in perspectivas], ensure_ascii=False),
          vetores))
    conn.commit()
    conn.close()

    # Gera e envia resumo no Telegram
    resumo = gera_resumo_telegram(tema, perspectivas, vetores)
    telegram(resumo)
    print(f"[Knowledge Daily] Ciclo completo. Resumo enviado no Telegram.")

    return {"ok": True, "tema": tema, "categoria": categoria, "vetores": vetores}

@app.get("/health")
def health():
    return {"ok": True, "service": "knowledge-daily"}

@app.get("/")
def root():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM historico")
    total = cur.fetchone()[0]
    cur.execute("SELECT data, categoria, tema, vetores_adicionados FROM historico ORDER BY id DESC LIMIT 5")
    historico = [{"data":r[0],"categoria":r[1],"tema":r[2],"vetores":r[3]} for r in cur.fetchall()]
    conn.close()
    return {"ok": True, "service": "knowledge-daily", "total_ciclos": total, "historico": historico}

@app.post("/executar")
def executar_manual():
    """Executa o ciclo manualmente — para teste ou forcado"""
    # Remove restricao de hoje para permitir execucao manual
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("DELETE FROM historico WHERE data=?", (str(datetime.date.today()),))
    conn.commit()
    conn.close()
    resultado = executar_knowledge_daily()
    return resultado

@app.get("/historico")
def ver_historico(limit: int = 10):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT data, categoria, tema, vetores_adicionados FROM historico ORDER BY id DESC LIMIT ?", (limit,))
    rows = [{"data":r[0],"categoria":r[1],"tema":r[2],"vetores":r[3]} for r in cur.fetchall()]
    conn.close()
    return {"ok": True, "historico": rows}

@app.get("/temas")
def ver_temas():
    return {"ok": True, "categorias": list(TEMAS.keys()),
            "total_temas": sum(len(v) for v in TEMAS.values())}

thread = threading.Thread(target=ciclo_diario, daemon=True)
thread.start()

if __name__ == "__main__":
    print("[Knowledge Daily] :5012 — auto-alimentacao diaria ativa")
    uvicorn.run(app, host="0.0.0.0", port=5012)
