#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase61_phase2_backlog_${TS}.json"
OUT_MD="docs/generated/phase61_phase2_backlog_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    phase: "FASE_2_AGENTE_VIVO_E_PROATIVO",
    modules: [
      {
        order: 1,
        module: "devops_agent",
        priority: "P0",
        objective: "dar ao JARVIS acesso controlado a shell, git, docker e logs",
        dependencies: ["git_repo_ok", "ssh_key_ok", "docker_access_ok"],
        done_when: [
          "responde ultimo_commit_github",
          "adiciona_log_hello_world_e_faz_deploy"
        ]
      },
      {
        order: 2,
        module: "dispatcher_api_ask",
        priority: "P0",
        objective: "rotear tarefas por categoria e expor POST /ask",
        dependencies: ["model_registry_ok"],
        done_when: [
          "curl_ask_funciona",
          "fallback_entre_modelos_funciona"
        ]
      },
      {
        order: 3,
        module: "vision_listener",
        priority: "P0",
        objective: "receber tarefas via redis e processar no VISION",
        dependencies: ["redis_pubsub_ok", "vision_core_ok", "ollama_ok"],
        done_when: [
          "jarvis_publica_task",
          "vision_processa",
          "vision_retorna_insight"
        ]
      },
      {
        order: 4,
        module: "vision_recruiter",
        priority: "P1",
        objective: "benchmarking dos modelos instalados e atualizacao do model_registry",
        dependencies: ["vision_listener", "model_benchmarks_table_ok"],
        done_when: [
          "benchmark_score_preenchido",
          "latencia_media_registrada"
        ]
      },
      {
        order: 5,
        module: "synaptic_pruning",
        priority: "P1",
        objective: "pausar e aposentar modelos por uso e falha",
        dependencies: ["vision_recruiter"],
        done_when: [
          "cron_definido",
          "policy_executada_sem_erros"
        ]
      },
      {
        order: 6,
        module: "user_preferences_learning",
        priority: "P1",
        objective: "aprender preferencias e influenciar roteamento",
        dependencies: ["vision_logs_ok", "user_preferences_table_ok"],
        done_when: [
          "preferencias_persistidas",
          "dispatcher_consulta_preferencias"
        ]
      },
      {
        order: 7,
        module: "observability_real",
        priority: "P1",
        objective: "dashboard e score refletindo dados reais multi-modelo",
        dependencies: ["dispatcher_api_ask", "vision_recruiter"],
        done_when: [
          "grafana_reflete_dados_reais",
          "relatorio_executivo_consistente"
        ]
      },
      {
        order: 8,
        module: "telegram_governance",
        priority: "P0",
        objective: "só crítico imediato; flap curto em log interno; 3 resumos por dia",
        dependencies: ["cooldown_ok", "flap_suppression_ok"],
        done_when: [
          "sem_metralhadora_de_alerta",
          "resumo_manha_tarde_noite"
        ]
      }
    ]
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 61 — Backlog Técnico da Fase 2

## Ordem sugerida
1. devops_agent
2. dispatcher_api_ask
3. vision_listener
4. vision_recruiter
5. synaptic_pruning
6. user_preferences_learning
7. observability_real
8. telegram_governance

## Meta
Sair do reativo para o preditivo, com presença contínua, contexto persistente e capacidade real de evolução assistida.
MD

echo "[OK] backlog da fase 2 gerado em ${OUT_JSON}"
echo "[OK] markdown do backlog gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
