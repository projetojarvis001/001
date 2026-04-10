#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase62_assisted_change_plan_${TS}.json"
OUT_MD="docs/generated/phase62_assisted_change_plan_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    objective: "preparar primeira mudanca assistida do DevOps Agent sem deploy real",
    change_unit: {
      name: "hello_world_log_change",
      risk: "LOW",
      scope: "controlado",
      deploy_real_now: false
    },
    steps: [
      {
        order: 1,
        step: "inspecionar_repositorio",
        done_when: "repo e branch identificados"
      },
      {
        order: 2,
        step: "capturar_ultimo_commit",
        done_when: "hash e resumo disponiveis"
      },
      {
        order: 3,
        step: "criar_arquivo_probe_controlado",
        done_when: "arquivo temporario gerado em runtime ou docs/generated"
      },
      {
        order: 4,
        step: "validar_sintaxe_shell_ou_codigo",
        done_when: "checagem verde"
      },
      {
        order: 5,
        step: "registrar_resultado_em_artefato_executivo",
        done_when: "json e markdown gerados"
      },
      {
        order: 6,
        step: "nao_fazer_deploy_real_ainda",
        done_when: "governanca mantida"
      }
    ],
    success_criteria: [
      "ultimo_commit_lido",
      "shell_controlado_ok",
      "docker_runtime_ok_ou_mapeado",
      "mudanca_minima_planejada",
      "nenhum_efeito_colateral_em_producao"
    ]
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 62 — Plano de Mudança Assistida Mínima

## Objetivo
Preparar a primeira mudança assistida do DevOps Agent sem deploy real.

## Escopo
- mudança: hello_world_log_change
- risco: LOW
- deploy_real_now: false

## Critérios de sucesso
- último commit lido
- shell controlado ok
- docker runtime ok ou mapeado
- mudança mínima planejada
- nenhum efeito colateral em produção
MD

echo "[OK] assisted change plan gerado em ${OUT_JSON}"
echo "[OK] markdown do plano gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
