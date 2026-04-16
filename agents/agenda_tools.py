
# PATCH agenda_server.py — integra Google Calendar
import sys, os, json, datetime
sys.path.insert(0, "/Users/jarvis001/Library/Python/3.9/lib/python/site-packages")

AGENDA_DB = "/Users/jarvis001/jarvis/data/agenda.json"

def carregar_agenda():
    if os.path.exists(AGENDA_DB):
        with open(AGENDA_DB) as f:
            return json.load(f)
    return {"visitas": [], "lembretes": []}

def salvar_agenda(data):
    os.makedirs(os.path.dirname(AGENDA_DB), exist_ok=True)
    with open(AGENDA_DB, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def agendar_visita(condominio: str, data: str, hora: str, sindico: str = "", telefone: str = "") -> dict:
    agenda = carregar_agenda()
    visita = {
        "id": f"v{len(agenda['visitas'])+1:04d}",
        "condominio": condominio,
        "data": data,
        "hora": hora,
        "sindico": sindico,
        "telefone": telefone,
        "status": "agendada",
        "created_at": datetime.datetime.now().isoformat()
    }
    agenda["visitas"].append(visita)
    salvar_agenda(agenda)
    return visita

def listar_visitas(dias=7) -> list:
    agenda = carregar_agenda()
    hoje = datetime.date.today()
    resultado = []
    for v in agenda.get("visitas", []):
        try:
            data_visita = datetime.date.fromisoformat(v.get("data","2099-01-01"))
            diff = (data_visita - hoje).days
            if 0 <= diff <= dias:
                resultado.append(v)
        except:
            pass
    return sorted(resultado, key=lambda x: x.get("data",""))
