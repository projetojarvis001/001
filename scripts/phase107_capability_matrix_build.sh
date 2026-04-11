#!/usr/bin/env bash
set -euo pipefail

mkdir -p capability runtime/capability logs/executive docs/generated

TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="capability/system_capability_matrix.json"
OUT_PHASE_JSON="logs/executive/phase107_capability_matrix_build_${TS}.json"
OUT_MD="docs/generated/phase107_capability_matrix_build_${TS}.md"

python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

capabilities = [
    {
        "name": "autonomo",
        "score": 38,
        "status": "parcial",
        "evidence": "rotinas automatizadas, watchdog, auditoria semanal, mas sem loop de decisao geral fechado",
        "gap": "orquestracao cross-node e acao sem operador"
    },
    {
        "name": "regenerativo",
        "score": 44,
        "status": "parcial",
        "evidence": "restore comprovado, fallback comprovado, drift rebaseline ativo",
        "gap": "self-healing automatico com rollback autonomo"
    },
    {
        "name": "machine_learning",
        "score": 6,
        "status": "baixo",
        "evidence": "nao ha pipeline real de treino inferencia feedback loop modelado",
        "gap": "coleta de dados, treino, serving e re-treino"
    },
    {
        "name": "adaptativo",
        "score": 28,
        "status": "baixo",
        "evidence": "ajustes manuais e baseline recalibrada",
        "gap": "mudanca dinamica de comportamento orientada por contexto"
    },
    {
        "name": "flexivel",
        "score": 52,
        "status": "moderado",
        "evidence": "scripts modulares, topologia formalizada, observabilidade separada",
        "gap": "mais nos ativos e menos acoplamento manual"
    },
    {
        "name": "inteligente",
        "score": 24,
        "status": "baixo",
        "evidence": "ha instrumentacao e trilha executiva, mas nao ha raciocinio operacional automatizado",
        "gap": "motor de decisao com memoria operacional"
    },
    {
        "name": "ubiquo",
        "score": 18,
        "status": "baixo",
        "evidence": "4 nos definidos, 1 ativo",
        "gap": "habilitar vision friday tadash com reachability real"
    },
    {
        "name": "preditivo",
        "score": 16,
        "status": "baixo",
        "evidence": "blackbox e observabilidade monitoram, mas nao antecipam",
        "gap": "predicao de falha, saturacao e risco"
    },
    {
        "name": "heuristico",
        "score": 20,
        "status": "baixo",
        "evidence": "scripts resolvem fluxos conhecidos",
        "gap": "resolver cenarios nao roteirizados"
    },
    {
        "name": "multimodal",
        "score": 4,
        "status": "baixo",
        "evidence": "nao ha processamento operacional integrado de audio video biometria",
        "gap": "pipelines multimodais reais"
    },
    {
        "name": "empatico",
        "score": 1,
        "status": "baixo",
        "evidence": "nao existe leitura de humor sarcasmo ou afeto",
        "gap": "camada conversacional emocional"
    },
    {
        "name": "contextual",
        "score": 34,
        "status": "parcial",
        "evidence": "historico por fases, logs executivos e topologia",
        "gap": "contexto dinamico por usuario, sessao e ambiente"
    },
    {
        "name": "simbiotico",
        "score": 0,
        "status": "ausente",
        "evidence": "nenhuma integracao biologica ou homem-maquina profunda",
        "gap": "interfaces biologicas e sinais humanos nativos"
    },
    {
        "name": "inexpugnavel",
        "score": 31,
        "status": "baixo",
        "evidence": "segredos locais endurecidos, trilha operacional e baseline",
        "gap": "hardening maior, rotacao de segredos, deteccao e resposta automatica"
    },
    {
        "name": "executivo",
        "score": 47,
        "status": "parcial",
        "evidence": "dashboard executivo, score, evidence, packet e checklist",
        "gap": "decisao automatizada com execucao cross-stack"
    }
]

overall = round(sum(item["score"] for item in capabilities) / len(capabilities), 1)

out = {
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "capability_matrix": {
        "overall_score": overall,
        "classification": (
            "fundacao_operacional_forte_mas_longe_de_ia_total"
            if overall < 50 else
            "intermediario"
        ),
        "capabilities": capabilities,
        "top_strengths": [
            "restore e fallback comprovados",
            "observabilidade implantada",
            "dashboard executivo e topologia formalizados"
        ],
        "top_gaps": [
            "multinode real ainda nao habilitado",
            "ausencia de ML verdadeiro",
            "ausencia de auto-decisao e auto-cura ampla",
            "ausencia de multimodalidade e contexto humano"
        ]
    }
}

Path("capability/system_capability_matrix.json").write_text(
    json.dumps(out, ensure_ascii=False, indent=2)
)
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg matrix_file "${OUT_JSON}" \
  '{
    created_at: $created_at,
    capability_matrix_build: {
      matrix_file: $matrix_file,
      overall_ok: true
    },
    governance: {
      deploy_executed: false,
      production_changed: false
    }
  }' > "${OUT_PHASE_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 107 — Capability Matrix Build

## Matrix
- matrix_file: ${OUT_JSON}

## Governança
- deploy_executed: false
- production_changed: false
MD

echo "[OK] phase107 build gerado em ${OUT_PHASE_JSON}"
cat "${OUT_PHASE_JSON}" | jq .
echo
echo "[OK] matrix em ${OUT_JSON}"
cat "${OUT_JSON}" | jq .
