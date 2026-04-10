#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase61_benchmark_reinforced_${TS}.json"
OUT_MD="docs/generated/phase61_benchmark_reinforced_${TS}.md"

jq -nc \
  --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    created_at: $created_at,
    suite_name: "phase61_reinforced_governance_suite",
    objective: "reduzir falso positivo, flap e regressao silenciosa",
    cases: [
      {
        id: "ops_flap_001",
        area: "telegram_alerting",
        title: "Oscilacao curta do VISION nao deve gerar rajada",
        expected: "log_interno_apenas"
      },
      {
        id: "ops_flap_002",
        area: "telegram_alerting",
        title: "Mensagem repetida deve respeitar cooldown",
        expected: "suppress_repeticao"
      },
      {
        id: "ops_recovery_003",
        area: "telegram_alerting",
        title: "Recuperacao deve gerar no maximo uma mensagem",
        expected: "single_recovery_message"
      },
      {
        id: "ops_timeout_004",
        area: "vision_health",
        title: "Timeout curto nao pode ser tratado como incidente critico imediatamente",
        expected: "estado_degradado_antes_de_critico"
      },
      {
        id: "ops_gate_005",
        area: "promotion",
        title: "Promocao com benchmark abaixo do gate deve bloquear",
        expected: "bloquear_promocao"
      },
      {
        id: "ops_gate_006",
        area: "promotion",
        title: "Promocao sem smoke verde deve bloquear",
        expected: "bloquear_promocao"
      },
      {
        id: "ops_release_007",
        area: "release_timeline",
        title: "Promocao saudavel nao deve herdar rollback antigo",
        expected: "rollback_not_run"
      },
      {
        id: "ops_exec_008",
        area: "executive_packet",
        title: "Packet diario deve refletir estado atual real",
        expected: "correlacao_artefatos_ok"
      }
    ],
    gate_policy: {
      benchmark_required: true,
      smoke_required: true,
      release_reliability_min_score: 70,
      operational_score_min_score: 80
    }
  }' > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 61 — Benchmark Reforçado

## Objetivo
Reduzir falso positivo, flap e regressão silenciosa.

## Casos
- ops_flap_001: Oscilação curta do VISION -> log interno apenas
- ops_flap_002: Mensagem repetida -> cooldown
- ops_recovery_003: Recuperação -> mensagem única
- ops_timeout_004: Timeout curto -> degradado antes de crítico
- ops_gate_005: Benchmark abaixo do gate -> bloqueio
- ops_gate_006: Smoke sem verde -> bloqueio
- ops_release_007: Promoção saudável -> não herdar rollback antigo
- ops_exec_008: Packet diário -> refletir estado atual

## Gate policy
- benchmark_required: true
- smoke_required: true
- release_reliability_min_score: 70
- operational_score_min_score: 80
MD

echo "[OK] benchmark reforcado gerado em ${OUT_JSON}"
echo "[OK] markdown do benchmark gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
