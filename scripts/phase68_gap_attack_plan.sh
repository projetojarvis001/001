#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

mkdir -p logs/executive docs/generated
TS="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="logs/executive/phase68_gap_attack_plan_${TS}.json"
OUT_MD="docs/generated/phase68_gap_attack_plan_${TS}.md"

SCORING_FILE="$(ls -1t logs/executive/phase68_component_scoring_*.json 2>/dev/null | head -n 1 || true)"
if [ -z "${SCORING_FILE}" ] || [ ! -f "${SCORING_FILE}" ]; then
  echo "[ERRO] scoring da fase 68 nao encontrado"
  exit 1
fi

jq '
  {
    created_at: .created_at,
    attack_order: [
      {
        order: 1,
        component: "VISION",
        rationale: "maior impacto no salto funcional do projeto"
      },
      {
        order: 2,
        component: "FRIDAY",
        rationale: "precisa ganhar presenca, contexto e utilidade executiva real"
      },
      {
        order: 3,
        component: "JARVIS",
        rationale: "ja esta forte; agora evolui por refinamento e integracao"
      },
      {
        order: 4,
        component: "ODOO",
        rationale: "entra no final, apos base central estar madura"
      }
    ],
    priorities: {
      immediate: ["VISION", "FRIDAY"],
      stabilization: ["JARVIS"],
      final_frontier: ["ODOO"]
    },
    decision: {
      operator_note: "A estrada do 10/10 passa primeiro por VISION e FRIDAY. JARVIS ja saiu da infancia operacional."
    }
  }
' "${SCORING_FILE}" > "${OUT_JSON}"

cat > "${OUT_MD}" <<MD
# FASE 68 — Gap Attack Plan

## Ordem de ataque
1. VISION
2. FRIDAY
3. JARVIS
4. ODOO

## Tese
- VISION é o maior multiplicador agora
- FRIDAY precisa sair do conceitual
- JARVIS já tem base forte
- ODOO fica para o fim, como combinado
MD

echo "[OK] gap attack plan gerado em ${OUT_JSON}"
echo "[OK] markdown do gap plan gerado em ${OUT_MD}"
cat "${OUT_JSON}" | jq .
