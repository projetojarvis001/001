#!/usr/bin/env python3
import sys, os, warnings, json, requests, re
warnings.filterwarnings("ignore")
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")
sys.path.insert(0, "/Users/jarvis001/jarvis/agents")
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

try:
    from cost_router import ask
except:
    from langchain_groq import ChatGroq
    from langchain_core.messages import HumanMessage
    _llm = ChatGroq(api_key=os.getenv("GROQ_API_KEY"), model="llama-3.3-70b-versatile", temperature=0)
    def ask(q, system="", **kwargs):
        r = _llm.invoke([HumanMessage(content=q)])
        return {"ok": True, "content": r.content}

BOT = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT = os.getenv("TELEGRAM_CHAT_ID")

CNAE_MAP = {
    "8219999": "Preparacao de documentos e servicos de apoio administrativo",
    "6201500": "Desenvolvimento de programas de computador sob encomenda",
    "6202300": "Desenvolvimento e licenciamento de programas de computador customizaveis",
    "6203100": "Desenvolvimento e licenciamento de programas de computador nao customizaveis",
    "6209100": "Suporte tecnico, manutencao e outros servicos em tecnologia da informacao",
    "6419300": "Bancos comerciais",
    "6422100": "Bancos multiplos com carteira comercial",
    "8011101": "Atividades de vigilancia e seguranca privada",
    "4321500": "Instalacao e manutencao eletrica",
    "4329101": "Instalacao de paineis publicitarios",
    "7490199": "Outras atividades profissionais, cientificas e tecnicas",
}

def cnae_descricao(codigo):
    codigo_str = str(codigo).replace(".","").replace("-","").replace("/","")[:7]
    if codigo_str in CNAE_MAP:
        return CNAE_MAP[codigo_str]
    # Tenta BrasilAPI NCM/CNAE
    try:
        import requests
        r = requests.get(f"https://brasilapi.com.br/api/cnae/v1/{codigo_str}", timeout=8)
        if r.status_code == 200:
            d = r.json()
            return d.get("descricao", codigo)
    except: pass
    return str(codigo)

def notify(msg):
    try:
        requests.post(f"https://api.telegram.org/bot{BOT}/sendMessage",
            json={"chat_id": CHAT, "text": msg, "parse_mode": "Markdown"}, timeout=10)
    except: pass

def consulta_cnpj(cnpj):
    cnpj_num = "".join(filter(str.isdigit, cnpj))
    
    # Tenta OpenCNPJ primeiro (mais completo)
    try:
        r = requests.get(f"https://api.opencnpj.org/{cnpj_num}", timeout=15)
        if r.status_code == 200:
            d = r.json()
            if d.get("razao_social"): return d
    except: pass
    
    # Fallback BrasilAPI
    try:
        r = requests.get(f"https://brasilapi.com.br/api/cnpj/v1/{cnpj_num}", timeout=15)
        if r.status_code == 200:
            d = r.json()
            if d.get("razao_social") or d.get("nome"): return d
    except: pass
    
    # Fallback ReceitaWS
    try:
        r = requests.get(f"https://receitaws.com.br/v1/cnpj/{cnpj_num}", timeout=15)
        if r.status_code == 200:
            d = r.json()
            if d.get("nome"): return d
    except: pass
    
    # Fallback CNPJ.ws
    try:
        r = requests.get(f"https://publica.cnpj.ws/cnpj/{cnpj_num}", timeout=15)
        if r.status_code == 200:
            d = r.json()
            if d.get("razao_social"): return d
    except: pass
    
    return None

def consulta_cep(cep):
    cep_num = "".join(filter(str.isdigit, cep))
    try:
        r = requests.get(f"https://brasilapi.com.br/api/cep/v2/{cep_num}", timeout=10)
        if r.status_code == 200: return r.json()
    except: pass
    return None

def consulta_selic():
    try:
        r = requests.get("https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados/ultimos/1?formato=json", timeout=10)
        if r.status_code == 200: return r.json()
    except: pass
    return None

def intel_report(query):
    cnpj_match = re.search(r"\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}", query)
    cep_match = re.search(r"\d{5}-?\d{3}", query)
    report_parts = []

    if cnpj_match:
        cnpj = cnpj_match.group()
        dados = consulta_cnpj(cnpj)
        if dados:
            rs = dados.get("razao_social") or dados.get("nome","?")
            fantasia = dados.get("nome_fantasia") or dados.get("fantasia","")
            sit = dados.get("descricao_situacao_cadastral") or dados.get("situacao_cadastral") or dados.get("situacao","?")
            
            # CNAE multiplos formatos
            cnae = dados.get("cnae_fiscal_descricao","")
            if not cnae and isinstance(dados.get("cnae_principal"), dict):
                cnae = dados["cnae_principal"].get("descricao","")
            if not cnae and dados.get("atividade_principal"):
                cnae = dados["atividade_principal"][0].get("text","")
            if not cnae:
                cnae = str(dados.get("cnae_principal","?"))
            
            abertura = dados.get("data_inicio_atividade") or dados.get("abertura","")
            porte = dados.get("porte","")
            if isinstance(porte, dict): porte = porte.get("descricao","")
            capital = dados.get("capital_social","")
            municipio = dados.get("municipio") or dados.get("cidade","")
            uf = dados.get("uf","")
            socios = dados.get("qsa",[])
            
            report_parts.append(f"CNPJ: {cnpj}")
            report_parts.append(f"Razao Social: {rs}")
            if fantasia and fantasia != rs: report_parts.append(f"Fantasia: {fantasia}")
            report_parts.append(f"Situacao: {sit}")
            if cnae and cnae != "?": report_parts.append(f"Atividade: {cnae_descricao(cnae)[:100]}")
            if abertura: report_parts.append(f"Abertura: {abertura}")
            if porte: report_parts.append(f"Porte: {porte}")
            if capital: report_parts.append(f"Capital Social: R$ {capital}")
            if municipio: report_parts.append(f"Cidade: {municipio}/{uf}")
            if socios:
                nomes = [s.get("nome_socio") or s.get("nome","?") for s in socios[:3]]
                report_parts.append(f"Socios: {', '.join(nomes)}")
            report_parts.append(f"CNAE: {cnae}")
            socios = dados.get("qsa",[])
            if socios:
                nomes = [s.get("nome_socio") or s.get("nome","?") for s in socios[:3]]
                report_parts.append(f"Socios: {', '.join(nomes)}")
        else:
            report_parts.append(f"CNPJ {cnpj}: dados nao encontrados")

    elif cep_match:
        cep = cep_match.group()
        dados = consulta_cep(cep)
        if dados:
            report_parts.append(f"CEP: {cep}")
            report_parts.append(f"Logradouro: {dados.get('street') or dados.get('logradouro','?')}")
            report_parts.append(f"Bairro: {dados.get('neighborhood') or dados.get('bairro','?')}")
            report_parts.append(f"Cidade: {dados.get('city') or dados.get('localidade','?')}")

    elif any(w in query.lower() for w in ["selic","juros","taxa"]):
        selic = consulta_selic()
        if selic:
            report_parts.append(f"Selic: {selic[0].get('valor','?')}% a.a.")
            report_parts.append(f"Data: {selic[0].get('data','?')}")

    if not report_parts:
        r = ask(query, system="Especialista em inteligencia de negocios brasileiro. Seja direto.")
        return r.get("content","Sem dados")

    raw = "\n".join(report_parts)
    analysis = ask(
        f"Dados:\n{raw}\n\nQuery: {query}\n\nAnalise executiva em 3 linhas.",
        system="Voce e o JARVIS. Seja direto e objetivo."
    )
    return raw + "\n\nAnalise: " + analysis.get("content","")

def run(query):
    result = intel_report(query)
    notify(f"Intel:\n{result[:3000]}")
    return result

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "selic"
    print(run(q))
