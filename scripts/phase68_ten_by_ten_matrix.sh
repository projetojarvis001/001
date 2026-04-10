#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase68_ten_by_ten_matrix_${TS}.json"
OUT_MD="docs/generated/phase68_ten_by_ten_matrix_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    framework: {
      name: "ten_by_ten_component_matrix",
      scale_min: 0,
      scale_max: 10,
      interpretation: "10 significa nivel operacional, tecnico e executivo de excelencia comprovada"
    },
    components: [
      {
        component: "JARVIS",
        dimensions: [
          "governanca_operacional",
          "devops_agent",
          "rotina_diaria",
          "observabilidade",
          "alertas_governados",
          "evidencia_executiva",
          "resiliencia",
          "automacao_controlada",
          "integracao_servicos",
          "prontidao_fase2"
        ]
      },
      {
        component: "VISION",
        dimensions: [
          "listener",
          "benchmark_modelos",
          "roteamento",
          "latencia",
          "disponibilidade",
          "qualidade_resposta",
          "fallback_modelos",
          "observabilidade_real",
          "recrutamento_modelos",
          "memoria_contextual"
        ]
      },
      {
        component: "FRIDAY",
        dimensions: [
          "presenca_operacional",
          "assistencia_executiva",
          "orquestracao_tarefas",
          "contexto_persistente",
          "interacao_natural",
          "qualidade_resumo",
          "priorizacao",
          "governanca",
          "estabilidade",
          "utilidade_real"
        ]
      },
      {
        component: "ODOO",
        dimensions: [
          "inventario_ambiente",
          "topologia",
          "backup_restore",
          "observabilidade",
          "seguranca_acesso",
          "documentacao",
          "integracao_jarvis",
          "integracao_alertas",
          "saude_servicos",
          "prontidao_intervencao"
        ]
      }
    ],
    scoring_rule: {
      "0": "inexistente",
      "3": "inicial",
      "5": "funcional_basico",
      "7": "bom_com_lacunas",
      "8": "forte",
      "9": "quase_excelencia",
      "10": "excelencia_comprovada"
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 68 — Matriz 10/10 por Componente

## Componentes
- JARVIS
- VISION
- FRIDAY
- ODOO

## Regra
Escala de 0 a 10 por dimensão.

## Interpretação
- 0: inexistente
- 3: inicial
- 5: funcional básico
- 7: bom com lacunas
- 8: forte
- 9: quase excelência
- 10: excelência comprovada
MD

echo "[OK] matrix 10/10 gerada em ${OUT_JSON}"
echo "[OK] markdown da matrix gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
